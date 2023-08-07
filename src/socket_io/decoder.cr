module SocketIO
  abstract class Decoder
    abstract def encode(packet : Packet) : String | Bytes
    abstract def decode(message : String | Bytes) : Packet
  end
end
