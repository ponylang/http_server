## Rename upgrade to upgrade_protocol

To allow changing the TCP handler of a running HTTP connection, `Session` specifies a method `upgrade_protocol`, which should be implemented by the concrete classes. The implementation used by the actual HTTP server had an implementation for this feature, but the method was called `upgrade`. As `Session` provides a default implementation for `upgrade_protocol`, this wasn't caught. By renaming the implementation it's now possible to use the new feature to change the handler to a custom handler to handle for example WebSocket connections.

