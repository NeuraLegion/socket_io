require "./packet"
require "./decoder"
require "msgpack"

module SocketIO
  class BaseDecoder < Decoder
    def encode(packet : Packet) : Bytes | String
      # TODO: handle binary attachments if we have them
      String.build do |s|
        s << "#{packet.type.value}"

        if packet.nsp && "/" != packet.nsp
          s << "#{packet.nsp},"
        end

        if packet.id
          s << "#{packet.id}"
        end

        if packet.data
          s << packet.data.to_json
        end
      end
    end

    def decode(message : Bytes | String) : Packet
      message = String.new(message) if message.is_a?(Bytes)
      i = 0

      type = PacketType.new(message[i].to_i)

      # TODO: look up attachments if type binary
      nsp = if message[i + 1] == '/'
        start = i + 1
        unless i = message.index(/[,]/, start)
          i = message.size
        end
        message[start..i - 1]
      else
        "/"
      end

      next_char = message[i + 1]
      id = if next_char && next_char.to_i64?
        start = i + 1
        unless i = message.index(/[^0-9]/, start)
          i = message.size
        end
        message[start..i - 1].to_i64
      else
        i += 1
        nil
      end

      data = parse_payload(message[i..]) if message[i]

      Packet.new(type: type, nsp: nsp, data: data, id: id)
    end

    private def parse_payload(value : String)
      begin
        JSON.parse(value)
      rescue ex : JSON::ParseException
        JSON::Any.new(value)
      end
    end
  end
end
