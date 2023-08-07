module EngineIO
  enum PacketType
    OPEN    = 0
    CLOSE   = 1
    PING    = 2
    PONG    = 3
    MESSAGE = 4
    UPGRADE = 5
    NOOP    = 6
  end

  struct Packet
    getter type : PacketType
    getter data : (String | Bytes)?

    def initialize(@type : PacketType, @data : (String | Bytes)? = nil)
    end
  end
end
