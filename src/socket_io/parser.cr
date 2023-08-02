module SocketIO
  abstract class Parser
    abstract def parse(x : Array)

    abstract def parse(x : Hash)

    abstract def parse(x)
  end
end
