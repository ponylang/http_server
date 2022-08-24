use "net"
use "collections"
use "valbytes"
use "debug"

actor _ServerConnection is Session
  """
  Manages a stream of requests coming into a server from a single client,
  dispatches those request to a back-end, and returns the responses back
  to the client.

  """
  let _protocol: _HTTPServerConnectionProtocol
  let _config: ServerConfig
  let _conn: TCPConnection
  let _timeout: _ServerConnectionTimeout = _ServerConnectionTimeout

  new create(
    handlermaker: HandlerFactory val,
    config: ServerConfig,
    conn: TCPConnection)
  =>
    """
    Create a connection actor to manage communication with to a new
    client. We also create an instance of the application's back-end
    handler that will process incoming requests.

    We always start with HTTP/1.x, and upgrade if necessary.
    """
    _protocol = _HTTPServerConnectionProtocol(
      handlermaker(this), config, conn, _timeout)
    _config = config
    _conn = conn

  be received(data: Array[U8] iso) =>
    _protocol.received(consume data)

  be closed() =>
    """
    Notification that the underlying connection has been closed.
    """
    _protocol.closed()

  be throttled() =>
    """
    TCP connection can not accept data for a while.
    """
    _protocol.throttled()

  be unthrottled() =>
    """
    TCP connection can not accept data for a while.
    """
    _protocol.unthrottled()

//// SEND RESPONSE API ////
//// STANDARD API

  be send_start(response: Response val, request_id: RequestID) =>
    """
    Initiate transmission of the HTTP Response message for the current
    Request.
    """
    _protocol._send_start(response, request_id)

  be send_chunk(data: ByteSeq val, request_id: RequestID) =>
    """
    Write low level outbound raw byte stream.
    """
    _protocol._send_chunk(data, request_id)

  be send_finished(request_id: RequestID) =>
    """
    We are done sending a response. We close the connection if
    `keepalive` was not requested.
    """
    _protocol._send_finished(request_id)

  be send_cancel(request_id: RequestID) =>
    """
    Cancel the current response.

    TODO: keep this???
    """
    _protocol._cancel(request_id)

//// CONVENIENCE API

  be send_no_body(response: Response val, request_id: RequestID) =>
    """
    Start and finish sending a response without a body.

    This function calls `send_finished` for you, so no need to call it yourself.
    """
    _protocol._send_start(response, request_id)
    _protocol._send_finished(request_id)

  be send(response: Response val, body: ByteArrays, request_id: RequestID) =>
    """
    Start and finish sending a response with body.
    """
    _protocol._send(response, body, request_id)

//// OPTIMIZED API

  be send_raw(raw: ByteSeqIter, request_id: RequestID, close_session: Bool = false) =>
    """
    If you have your response already in bytes, and don't want to build an expensive
    [Response](http_server-Response) object, use this method to send your [ByteSeqIter](builtin-ByteSeqIter).
    This `raw` argument can contain only the response without body,
    in which case you can send the body chunks later on using `send_chunk`,
    or, to further optimize your writes to the network, it might already contain
    the response body.

    If the session should be closed after sending this response,
    no matter the requested standard HTTP connection handling,
    set `close_session` to `true`. To be a good HTTP citizen, include
    a `Connection: close` header in the raw response, to signal to the client
    to also close the session.
    If set to `false`, then normal HTTP connection handling applies
    (request `Connection` header, HTTP/1.0 without `Connection: keep-alive`, etc.).

    In each case, finish sending your raw response using `send_finished`.
    """
    _protocol._send_raw(raw, request_id, close_session)

  be dispose() =>
    """
    Close the connection from the server end.
    """
    _conn.dispose()

  be _mute() =>
    _conn.mute()

  be _unmute() =>
    _conn.unmute()

//// Timeout API

  be _heartbeat(current_seconds: I64) =>
    let timeout = _config.connection_timeout.i64()
    //Debug("current_seconds=" + current_seconds.string() + ", last_activity=" + _timeout._last_activity_ts.string())
    if (timeout > 0) and ((current_seconds - _timeout.last_activity_ts()) >= timeout) then
      //Debug("Connection timed out.")
      // backend is notified asynchronously when the close happened
      dispose()
    end

