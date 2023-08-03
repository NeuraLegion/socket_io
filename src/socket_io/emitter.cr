require "./event"
require "json"

module SocketIO
  alias EventHandler = Event ->

  class Emitter
    @listeners : Hash(String, Array(EventHandler)) = Hash(String, Array(EventHandler)).new
    @mutex : Mutex = Mutex.new

    def on(event : String, &block : EventHandler)
      @mutex.synchronize do
        @listeners[event] ||= [] of EventHandler
        @listeners[event] << block
      end
    end

    def off(event : String, &block : EventHandler)
      @mutex.synchronize do
        return unless @listeners[event]?
        @listeners[event].delete(block)
      end
    end

    def off(event : String)
      @mutex.synchronize { @listeners.delete(event) }
    end

    def off_all
      @mutex.synchronize { @listeners.clear }
    end

    def emit(event : String)
      emit(event)
    end

    def emit(event_name : String, event : Event)
      listeners = @mutex.synchronize do
        @listeners[event_name]?.dup
      end

      return unless listeners

      listeners.each do |listener|
        spawn do
          listener.call(event)
        end
      end
    end
  end
end
