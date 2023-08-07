# socket_io

TODO: Write a description here

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     socket_io:
       github: NeuraLegion/socket_io
   ```

2. Run `shards install`

## Usage

To get started, require the `socket_io` library in your Crystal code:

```cr
require "socket_io"
```

Next, create a new Socket.IO client and connect it to the server:

```cr
socket = SocketIO::Client.new(host: "<your-hostname>")
socket.connect
```

You can emit events to the server using the `emit` method:

```cr
socket.emit("hello", "world")
```

Additionally, you can emit events and expect an acknowledgement from the server:

```cr
data = socket.emit_with_ack("hello", "world")
```

To customize the acknowledgement timeout, you can add the timeout argument:

```cr
data = socket.emit_with_ack("hello", "world", timeout: 60.seconds)
```

To handle incoming events, use the `on` method as follows:

```cr
socket.on("news") do |event|
  puts event.data
end
```

To acknowledge an event, simply use the ack method as shown below:

```cr
socket.on("request") do |event|
  event.ack("response")
end
```

To remove event listeners, utilize one of the existing methods:

```cr
# Remove a specific listener
socket.off("my-event", &my_listener)

# Remove all event listeners for a specific event
socket.off("my-event")

# Remove all event listeners for all events
socket.off_all()

```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/NeuraLegion/socket_io/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Bar Hofesh](https://github.com/bararchy) - creator and maintainer
