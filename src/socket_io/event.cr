module SocketIO
  class Event
    getter id : UInt64?
    getter data : Array(JSON::Any)?

    @client : Client
    @acknowledged = Atomic::Flag.new

    def initialize(@client : Client, @id : UInt64? = nil, @data : Array(JSON::Any)? = nil)
    end

    def ack(*data)
      id = @id
      return unless id
      @client.ack(*data, id: id) if @acknowledged.test_and_set
    end
  end
end
