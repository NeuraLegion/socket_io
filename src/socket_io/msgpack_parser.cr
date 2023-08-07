require "./parser"
require "msgpack"

module SocketIO
  class MsgpackParser < Parser
    def parse(x : JSON::Any)
      value = case x
      when .as_h?
        x.as_h
      when .as_a?
        x.as_a
      when .as_s?
        x.as_s
      when .as_f?
        x.as_f
      when .as_i?
        x.as_i
      when .as_i64?
        x.as_i64
      when .as_bool?
        x.as_bool
      else
        nil
      end
      parse(value)
    end

    def parse(x : Array)
      return x.map { |e| parse(e).as(MessagePack::Type) }
    end

    def parse(x : Hash)
      h = {} of String => MessagePack::Type
      x.each_with_object(h) do |(k, v), h|
        h[k.as(String)] = parse(v).as(MessagePack::Type)
      end
      h
    end

    def parse(x)
      x.as(MessagePack::Type)
    end
  end
end
