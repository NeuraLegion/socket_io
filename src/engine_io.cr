require "http/web_socket"
require "json"

module EngineIO
  Log = ::Log.for("EngineIO")
  backend = ::Log::IOBackend.new(STDOUT)
  ::Log.setup do |c|
    c.bind("EngineIO.*", ::Log::Severity::Error, backend)
  end

  enum PacketType
    OPEN    = 0
    CLOSE   = 1
    PING    = 2
    PONG    = 3
    MESSAGE = 4
    UPGRADE = 5
    NOOP    = 6
  end

  class Client
    @websocket : HTTP::WebSocket
    @ping_interval : Int32 = 25000
    @ping_timeout : Int32 = 60000
    @max_payload : Int64 = 100000000
    @connected : Atomic(Int32) = Atomic(Int32).new(0)
    @incoming : Channel(String) = Channel(String).new(100)

    def initialize(host : String, path : String = "/engine.io")
      @websocket = HTTP::WebSocket.new("wss://#{host}#{path}?EIO=4&transport=websocket")
    end

    def send(message : String)
      send_packet(PacketType::MESSAGE, message)
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
      send_packet(PacketType::CLOSE)
    end

    def run
      @websocket.on_message do |message|
        Log.debug { "Received message #{message}" }
        case PacketType.new(message[0].to_i)
        when PacketType::OPEN
          json = JSON.parse(message[1..-1])
          @ping_interval = json["pingInterval"].as_i
          @ping_timeout = json["pingTimeout"].as_i
          @max_payload = json["maxPayload"].as_i64
          @connected.set(1)
        when PacketType::CLOSE
          @websocket.close
        when PacketType::PING
          send_packet(PacketType::PONG)
        when PacketType::PONG
          # do nothing
        when PacketType::MESSAGE
          @incoming.send(message[1..-1])
        when PacketType::UPGRADE
          # do nothing
        when PacketType::NOOP
          # do nothing
        end
      end
    end

    private def send_packet(type : PacketType, data : String = "")
      Log.debug { "Sending packet #{type.value}#{data}" }
      @websocket.send("#{type.value}#{data}")
    end
  end
end
