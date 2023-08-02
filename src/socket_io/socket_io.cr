require "../engine_io"
require "./decoder"
require "./base_decoder"
require "./packet"
require "./json_parser"

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

    def initialize(host : String, path : String = "/socket.io/", @namespace : String = "/", base64 : Bool = false, @decoder : Decoder = BaseDecoder.new)
      @engine_io = EngineIO::Client.new(host: host, path: path, base64: base64)
      spawn do
        @engine_io.connect
      end
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

    def send(data, type : PacketType = PacketType::EVENT, id : Int64? = nil)
      case type
      when PacketType::EVENT, PacketType::ACK, PacketType::BINARY_EVENT, PacketType::BINARY_ACK
        data = [data] unless data.is_a?(Array)
      end
      emit(type, data, id)
    end

    def emit(event : PacketType, data = nil?, id : Int64? = nil)
      packet = Packet.new(
        type: event,
        nsp: @namespace,
        data: JSON::Any.new(@parser.parse(data)),
        id: id
      )
      msg = @decoder.encode(packet)
      @engine_io.send(msg)
    end

    def connect(data = nil?)
      emit(PacketType::CONNECT, data)
    end

    def disconnect
      emit(PacketType::DISCONNECT)
    end

    def close
      disconnect
    end

    def on_data
      @engine_io.on_message do |data|
        message = @decoder.decode(data)
        Log.debug { "Received #{message.type} packet with namespace #{message.nsp} and data #{message.data}" }
        case message.type
        when PacketType::EVENT, PacketType::ACK, PacketType::BINARY_EVENT, PacketType::BINARY_ACK
          yield message
        when PacketType::DISCONNECT
          close
        end
      end
    end
  end
end
