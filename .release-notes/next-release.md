## Add `Session.upgrade_protocol` behaviour

This can be used to upgrade the underlying TCP connection to a new incompatible protocol, like websockets.

Calling this new behaviour allows this TCP connection to be upgraded to another handler, serving another protocol (e.g. [WebSocket](https://www.rfc-editor.org/rfc/rfc6455.html)).

Note that this method does not send an HTTP Response with a status of 101. This needs to be done before calling this behaviour. Also, the passed in `notify` will not have its methods [accepted](https://stdlib.ponylang.io/net-TCPConnectionNotify/#connected) or [connected](https://stdlib.ponylang.io/net-TCPConnectionNotify/#connected) called, as the connection is already established.

After calling this behaviour, this session and the connected Handler instance will not be called again, so it is necessary to do any required clean up right after this call.

See:
  - [Protocol Upgrade Mechanism](https://developer.mozilla.org/en-US/docs/Web/HTTP/Protocol_upgrade_mechanism)
  - [Upgrade Header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Upgrade)
