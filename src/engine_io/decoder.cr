require "./packet"
require "base64"

module EngineIO
  class Decoder
    getter base64 : Bool

    def initialize(@base64 : Bool = false)
    end

    def decode(encoded_packet : String | Bytes) : Packet
      if encoded_packet.is_a?(String)
        if encoded_packet.starts_with?("b")
          data = Base64.decode(encoded_packet[1..-1])
          return Packet.new(type: PacketType::MESSAGE, data: data)
        else
          return Packet.new(type: PacketType.new(encoded_packet[0].to_i), data: encoded_packet[1..-1])
        end
      end

      Packet.new(type: PacketType::MESSAGE, data: encoded_packet)
    end

    def encode(decoded_packet : Packet) : String | Bytes
      payload = decoded_packet.data

      if payload.is_a?(Bytes)
        if @base64
          return "b#{Base64.encode(payload)}"
        else
          return payload
        end
      end

      "#{decoded_packet.type.value}#{payload}"
    end
  end
end
