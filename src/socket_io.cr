require "msgpack"

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
    @msgpack : Bool

    def initialize(host : String, path : String = "/socket.io", @namespace : String = "", @msgpack : Bool = false)
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

    def send(data : String, type : PacketType = PacketType::EVENT, id : Int64? = nil)
      # Sent event packet
      emit(type, "[#{data}]", id)
    end

    def emit(event : PacketType, data : String, id : Int64? = nil)
      # Sent event packet
      if @msgpack
        msg = String.new(
          {
            type: event.value,
            nsp:  @namespace,
            data: data,
            id:   id,
          }.to_msgpack
        )
      else
        msg = "#{event.value}#{@namespace},#{id}#{data}"
      end
      @engine_io.send(msg)
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
        if @msgpack
          Log.debug { "Received msgpack data #{data}" }
          temp = MSGPackParser.from_msgpack(data)
          message = Packet.new(
            type: PacketType.new(temp.type),
            namespace: temp.nsp,
            data: JSON.parse(temp.data),
            id: temp.id
          )
        else
          message = Packet.new(data)
        end
        message = Packet.new(data)
        Log.debug { "Received #{message.type} packet with namespace #{message.namespace} and data #{message.data}" }
        case message.type
        when PacketType::EVENT, PacketType::ACK, PacketType::BINARY_EVENT, PacketType::BINARY_ACK
          yield message
        when PacketType::DISCONNECT
          close
        end
      end
    end

    class MSGPackParser
      include MessagePack::Serializable

      property type : PacketType
      property nsp : String
      property data : String
      property id : Int64?

      def initialize(@type : PacketType, @nsp : String, @data : String, @id : Int64? = nil)
      end
    end

    struct Packet
      getter type : PacketType
      getter namespace : String
      getter id : Int64?
      getter data : JSON::Any

      def initialize(@type : PacketType, @namespace : String, @data : JSON::Any, @id : Int64? = nil)
      end

      def initialize(data : String)
        @type = PacketType.new(data[0].to_i)

        @namespace, payload = data[1..-1].split(",", 2)
        case @type
        when PacketType::EVENT, PacketType::ACK
          id, raw = payload.split("[", 2)
          raw = "[" + raw
          @id = id.to_i64?
          @data = JSON.parse(raw)
        else
          @data = JSON.parse(payload)
        end
      end
    end
  end
end
