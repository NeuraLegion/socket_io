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

```crystal
require "socket_io"
socket = SocketIO::Client.new(host: hostname, path: "/socketio", namespace: "/")
socket.connect

socket.on_data do |packet|
  # packet.type
  # packet.namespace
  # packet.id
  # packet.data -> JSON data object
end

socket.send("data")
socket.send("{}")
socket.send(data: "data", id: 123, type: :ack)
```

TODO: Write usage instructions here

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
