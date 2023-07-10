require "./engine_io.cr"

module SocketIO
  VERSION = "4"

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
    end

    def send(data : String)
      # Sent event packet
      emit(PacketType::EVENT, "[#{data}]")
    end

    def emit(event : PacketType, data : String)
      # Sent event packet
      @engine_io.send("#{event.value}#{@namespace},#{data}")
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

    def on_data(&block : JSON::Any ->)
      @engine_io.on_message do |data|
        message = Packet.new(data)
        puts "Received #{message.type} packet with namespace #{message.namespace} and data #{message.data}"
        block.call(message.data)
      end
    end

    struct Packet
      getter type : PacketType
      getter namespace : String
      getter data : JSON::Any

      def initialize(data : String)
        # Packet looks like this: PacketType/namespace,data
        # Data is a JSON object
        parts = data.split(",", 2)
        @type = PacketType.from_value(parts[0].to_i)
        @namespace = parts[1].split("/", 2)[0]
        @data = JSON.parse(parts[1].split(",", 2)[1])
      end
    end
  end
end
