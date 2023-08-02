module SocketIO
  enum PacketType
    CONNECT       = 0
    DISCONNECT    = 1
    EVENT         = 2
    ACK           = 3
    CONNECT_ERROR = 4
    BINARY_EVENT  = 5
    BINARY_ACK    = 6
  end

  struct Packet
    getter type : PacketType
    getter nsp : String?
    getter id : Int64?
    getter data : JSON::Any?

    def initialize(@type : PacketType, @nsp : String? = nil, @data : JSON::Any? = nil, @id : Int64? = nil)
    end
  end
end
