module SocketIO
  class CorrelationID
    @@next_number : Int64 = 1
    @@mutex = Mutex.new

    def self.next_number : Int64
      @@mutex.lock
      number = @@next_number
      @@next_number += 1
      @@mutex.unlock
      number
    end
  end
end
