use "net"
use "debug"

class _ServerConnHandler is TCPConnectionNotify
  """
  This is the network notification handler for the server.
  It handles I/O for a single HTTP connection (which includes at least
  one HTTP request, and possibly more with Keep-Alive). It parses HTTP
  requests and forwards them to the session it is bound to.
  Functions in this class execute within the `TCPConnection` actor.
  """
  let _handlermaker: HandlerFactory val
  let _registry: _SessionRegistry tag
  let _config: ServerConfig

  var _parser: (HTTP11RequestParser | None) = None
  var _session: (_ServerConnection | None) = None

  new iso create(
    handlermaker: HandlerFactory val,
    registry: _SessionRegistry,
    config: ServerConfig)
    =>
    """
    Initialize the context for parsing incoming HTTP requests.
    """
    _handlermaker = handlermaker
    _registry = registry
    _config = config

  fun ref accepted(conn: TCPConnection ref) =>
    """
    Accept the incoming TCP connection and create the actor that will
    manage further communication, and the message parser that feeds it.
    """
    let sconn = _ServerConnection(_handlermaker, _config, conn)
    _registry.register_session(sconn)
    _session = sconn
    _parser = HTTP11RequestParser.create(sconn)

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8] iso,
    times: USize)
    : Bool
  =>
    """
    Pass chunks of data to the `HTTP11RequestParser` for this session. It will
    then pass completed information on the `Session`.
    """
    // TODO: inactivity timer
    // add a "reset" API to Timers

    match _parser
    | let b: HTTP11RequestParser =>
      // Let the parser take a look at what has been received.
      let res = b.parse(consume data)
      match res
      // Any syntax errors will terminate the connection.
      | let rpe: RequestParseError =>
        Debug("Parser: RPE")
        conn.close()
      | NeedMore =>
        Debug("Parser: NeedMore")
      end
    end
    true

  fun ref throttled(conn: TCPConnection ref) =>
    """
    Notification that the TCP connection to the client can not accept data
    for a while.
    """
    try
      (_session as _ServerConnection).throttled()
    end

  fun ref unthrottled(conn: TCPConnection ref) =>
    """
    Notification that the TCP connection can resume accepting data.
    """
    try
      (_session as  _ServerConnection).unthrottled()
    end

  fun ref closed(conn: TCPConnection ref) =>
    """
    The connection has been closed. Abort the session.
    """
    try
      let sconn = (_session as _ServerConnection)
      _registry.unregister_session(sconn)
      sconn.closed()
    end

  fun ref connect_failed(conn: TCPConnection ref) =>
    None

