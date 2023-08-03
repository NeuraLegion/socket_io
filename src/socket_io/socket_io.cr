require "../engine_io"
require "./decoders/base_decoder"
require "./decoder"
require "./packet"
require "./json_parser"
require "./event"
require "./emitter"
require "./correlation_id"

module SocketIO
  VERSION = "5"

  Log = ::Log.for("SocketIO")
  backend = ::Log::IOBackend.new(STDOUT)
  ::Log.setup do |c|
    c.bind("SocketIO.*", ::Log::Severity::Error, backend)
  end

  class Client
    @engine_io : EngineIO::Client
    @namespace : String
    @decoder : Decoder
    @parser : JsonParser = JsonParser.new
    @emitter : Emitter = Emitter.new
    @acks : Hash(UInt64, Channel(Packet)) = Hash(UInt64, Channel(Packet)).new
    @acks_mutex = Mutex.new

    def initialize(host : String, path : String = "/socket.io/", @namespace : String = "/", base64 : Bool = false, @decoder : Decoder = Decoders::BaseDecoder.new)
      @engine_io = EngineIO::Client.new(host: host, path: path, base64: base64)

      spawn do
        @engine_io.connect
      end

      on_packet

      # Wait up to 30 seconds for engine to connect
      30.times do
        break if @engine_io.connected?
        sleep 1
      end

      unless @engine_io.connected?
        Log.error { "Could not connect to engine.io server" }
        raise "Could not connect to engine.io server"
      end
    end

    def on(event_name : String, &block : EventHandler)
      @emitter.on(event_name, &block)
    end

    def off(event_name : String, &block : EventHandler)
      @emitter.off(event_name, &block)
    end

    def off(event_name : String)
      @emitter.off(event_name)
    end

    def emit(event_name : String, *data)
      emit_event(event_name, *data)
    end

    # TODO: should we consider replacing the Event class and
    #   this public method with a simpler callback approach?
    #
    # ```diff
    # -socket.on("request") do |event|
    # +socket.on("request") do |data, callback|
    #   # ...
    # -  event.ack({
    # +  callback.call({
    #     # ...
    #   })
    # end
    # ```
    def ack(*data, id : UInt64)
      packet = create_packet(PacketType::ACK, data, id)
      send_packet(packet)
    end

    def emit_with_ack(event_name : String, *data, timeout : Time::Span = 30.seconds)
      id = CorrelationID.next_number
      ack_channel = @acks_mutex.synchronize { @acks[id] = Channel(Packet).new(1) }
      emit_event(event_name, *data, id: id)
      receive_ack_or_raise_timeout(ack_channel, timeout)
    ensure
      @acks_mutex.synchronize { @acks.delete(id) }
    end

    def connect(data = Hash(String, String).new)
      packet = create_packet(PacketType::CONNECT, data)
      send_packet(packet)
    end

    def disconnect
      @emitter.off_all
      @acks_mutex.synchronize do
        @acks.each_value(&.close)
        @acks.clear
      end
      packet = create_packet(PacketType::DISCONNECT, nil)
      send_packet(packet)
    end

    def close
      disconnect
    end

    private def emit_event(*data, id : UInt64? = nil)
      packet = create_packet(PacketType::EVENT, data, id)
      send_packet(packet)
    end

    private def create_packet(type : PacketType, data, id : UInt64? = nil)
      Packet.new(
        id: id,
        type: type,
        nsp: @namespace,
        data: JSON::Any.new(@parser.parse(data)),
      )
    end

    private def send_packet(packet : Packet)
      msg = @decoder.encode(packet)
      @engine_io.send(msg)
    end

    private def receive_ack_or_raise_timeout(channel : Channel(Packet), timeout : Time::Span)
      select
      when packet = channel.receive?
        raise "Invalid ack packet" unless packet
        extract_event_data(packet)
      when timeout(timeout)
        raise "Timeout while waiting for a message."
      end
    end

    private def on_packet
      @engine_io.on_packet do |data|
        packet = @decoder.decode(data)
        Log.debug { "Received #{packet.type} packet with namespace #{packet.nsp} and data #{packet.data}" }
        case packet.type
        when PacketType::EVENT, PacketType::ACK, PacketType::BINARY_EVENT, PacketType::BINARY_ACK
          handle_event_message(packet)
        when PacketType::DISCONNECT
          close
        end
      end
    end

    private def handle_event_message(packet : Packet)
      ack_channel = @acks_mutex.synchronize { @acks[packet.id]? if packet.id }

      if ack_channel
        ack_channel.send(packet)
      else
        event_name, *args = extract_event_data(packet)
        # TODO: preserve the offset for delivery guarantees
        event = Event.new(id: packet.id, data: args, client: self)
        @emitter.emit(event_name.as_s, event)
      end
    end

    private def extract_event_data(message)
      raise "Invalid payload" unless payload = message.data
      payload.as_a
    end
  end
end
