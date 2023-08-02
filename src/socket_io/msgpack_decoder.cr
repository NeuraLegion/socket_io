require "./packet"
require "./decoder"
require "./json_parser"
require "./msgpack_parser"
require "msgpack"

module SocketIO
  class MsgpackDecoder < Decoder
    @msgpack_parser : MsgpackParser
    @json_parser : JsonParser

    def initialize
      @msgpack_parser = MsgpackParser.new
      @json_parser = JsonParser.new
    end

    def encode(packet : Packet) : Bytes | String
      {
        type: packet.type.value,
        nsp:  packet.nsp,
        data: @msgpack_parser.parse(packet.data),
      }.to_msgpack
    end

    def decode(message : String | Bytes) : Packet
      decoded_packet = Hash(String, MessagePack::Type).from_msgpack(message)
      Packet.new(
        type: PacketType.new(decoded_packet["type"].as(UInt8)),
        nsp: decoded_packet["nsp"].as(String),
        data: JSON::Any.new(@json_parser.parse(decoded_packet["data"])),
        id: decoded_packet["id"]?.as(Int64 | Nil)
      )
    end
  end
end
