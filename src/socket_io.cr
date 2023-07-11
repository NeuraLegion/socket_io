require "./engine_io.cr"

module SocketIO
  VERSION = "4"

  Log = ::Log.for("SocketIO")
  backend = ::Log::IOBackend.new(STDOUT)
  ::Log.setup do |c|
    c.bind("SocketIO.*", ::Log::Severity::Error, backend)
  end

  enum PacketType
    CONNECT       = 0
    DISCONNECT    = 1
    EVENT         = 2
    ACK           = 3
    CONNECT_ERROR = 4
    BINARY_EVENT  = 5
    BINARY_ACK    = 6
  end

  class Client
    @engine_io : EngineIO::Client
    @namespace : String

    def initialize(host : String, path : String = "/socket.io", @namespace : String = "")
      @engine_io = EngineIO::Client.new(host: host, path: path)
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

    def send(data : String, type : PacketType = PacketType::EVENT, id : Int32? = nil)
      # Sent event packet
      emit(type, "[#{data}]", id)
    end

    def emit(event : PacketType, data : String, id : Int32? = nil)
      # Sent event packet
      @engine_io.send("#{event.value}#{@namespace},#{id}#{data}")
    end

    def connect
      # Sent connect packet
      emit(PacketType::CONNECT, "")
    end

    def connect(data : String)
      # Sent connect packet
      emit(PacketType::CONNECT, data)
    end

    def disconnect
      # Sent disconnect packet
      emit(PacketType::DISCONNECT, "")
    end

    def close
      disconnect
    end

    def on_data
      @engine_io.on_message do |data|
        message = Packet.new(data)
        Log.debug { "Received #{message.type} packet with namespace #{message.namespace} and data #{message.data}" }
        case message.type
        when PacketType::EVENT, PacketType::ACK
          yield message
        when PacketType::DISCONNECT
          close
        end
      end
    end

    struct Packet
      getter type : PacketType
      getter namespace : String
      getter id : Int32?
      getter data : JSON::Any

      def initialize(data : String)
        @type = PacketType.new(data[0].to_i)

        @namespace, payload = data[1..-1].split(",", 2)

        id, raw = payload.split("[", 2)
        raw = "[" + raw
        @id = id.to_i?
        @data = JSON.parse(raw)
      end
    end
  end
end
