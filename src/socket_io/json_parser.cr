require "./parser"
require "json"

module SocketIO
  class JsonParser < Parser
    macro add_methods_to_cast_unint_and_int(*types)
      {% for type in types %}
        def parse(value : {{type.id}})
          value.to_i64
        end
      {% end %}
    end

    def parse(x : Tuple)
      parse(x.to_a)
    end

    def parse(x : NamedTuple)
      parse(x.to_h)
    end

    def parse(x : Symbol)
      parse(x.to_s)
    end

    def parse(x : Array)
      return x.map { |e| JSON::Any.new(parse(e).as(JSON::Any::Type)) }.as(JSON::Any::Type)
    end

    def parse(x : Hash)
      h = {} of String => JSON::Any
      x.each_with_object(h) do |(k, v), h|
        k = k.to_s if k.is_a?(Symbol)
        h[k.as(String)] = JSON::Any.new(parse(v).as(JSON::Any::Type))
      end
      h.as(JSON::Any::Type)
    end

    add_methods_to_cast_unint_and_int(Int8,
      Int16,
      Int32,
      Int128,
      UInt8,
      UInt16,
      UInt32,
      UInt64,
      UInt128
    )

    def parse(x)
      x.as(JSON::Any::Type)
    end
  end
end
