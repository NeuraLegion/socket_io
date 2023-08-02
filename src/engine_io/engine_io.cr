require "./packet"
require "./decoder"
require "http/web_socket"
require "json"

module EngineIO
  VERSION = "4"

  Log = ::Log.for("EngineIO")
  backend = ::Log::IOBackend.new(STDOUT)
  ::Log.setup do |c|
    c.bind("EngineIO.*", ::Log::Severity::Error, backend)
  end

  class Client
    @websocket : HTTP::WebSocket
    @ping_interval : Int32 = 25000
    @ping_timeout : Int32 = 60000
    @max_payload : Int64 = 100000000
    @connected : Atomic(Int32) = Atomic(Int32).new(0)
    @incoming : Channel(String | Bytes) = Channel(String | Bytes).new(100)
    @decoder : Decoder

    def initialize(host : String, path : String = "/engine.io", base64 : Bool = false)
      @decoder = Decoder.new(base64)
      url = build_url(host, path, base64)
      @websocket = HTTP::WebSocket.new(url)
    end

    def send(message : String)
      send_packet(Packet.new(type: PacketType::MESSAGE, data: message))
    end

    def send(message : Bytes)
      send_packet(Packet.new(type: PacketType::MESSAGE, data: message))
    end

    def on_message
      loop do
        yield @incoming.receive
      end
    end

    def connect
      run
      @websocket.run
    end

    def connected? : Bool
      @connected.get == 1
    end

    def close
      send_packet(Packet.new(type: PacketType::CLOSE))
    end

    def run
      @websocket.on_binary do |message|
        handle_packet(message)
      end

      @websocket.on_message do |message|
        handle_packet(message)
      end
    end

    def handle_packet(message : String | Bytes)
      packet = @decoder.decode(message)
      Log.debug { "Received message #{packet}" }
      case packet.type
      when PacketType::OPEN
        handle_open_packet(packet)
      when PacketType::CLOSE
        handle_close_packet(packet)
      when PacketType::PING
        handle_ping_packet(packet)
      when PacketType::MESSAGE
        handle_message_packet(packet)
      when PacketType::UPGRADE, PacketType::NOOP, PacketType::PONG
        # do nothing
      end
    end

    private def handle_open_packet(packet : Packet)
      packet_data = packet.data
      unless packet_data.is_a?(String)
        Log.debug { "Parse error. Invalid payload: #{packet_data}" }
      else
        json = JSON.parse(packet_data)
        @ping_interval = json["pingInterval"].as_i
        @ping_timeout = json["pingTimeout"].as_i
        @max_payload = json["maxPayload"].as_i64
        @connected.set(1)
      end
    end

    private def handle_close_packet(packet : Packet)
      @websocket.close
      @connected.set(0)
    end

    private def handle_ping_packet(packet : Packet)
      send_packet(Packet.new(type: PacketType::PONG))
    end

    private def handle_message_packet(packet : Packet)
      packet_data = packet.data
      if packet_data.nil?
        Log.debug { "Parse error. Invalid payload: #{packet_data}" }
      else
        @incoming.send(packet_data)
      end
    end

    private def send_packet(packet : Packet)
      Log.debug { "Sending packet #{packet}" }
      message = @decoder.encode(packet)
      @websocket.send(message)
    end

    private def build_url(host : String, path : String, base64 : Bool)
      params = URI::Params.build do |form|
        form.add("EIO", VERSION)
        form.add("transport", "websocket")
        form.add("b64", true.to_s) if base64
      end

      "wss://#{host}#{path}?#{params.to_s}"
    end
  end
end
