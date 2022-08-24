use "net"
use "valbytes"
use "debug"

class _HTTPServerConnectionProtocol is _ServerConnectionProtocol
  let _backend: Handler
  let _config: ServerConfig
  let _conn: TCPConnection
  let _state: _HTTPServerConnectionState
  let _parser: HTTP11RequestParser
  let _timeout: _ServerConnectionTimeout

  new create(
    backend: Handler,
    config: ServerConfig,
    conn: TCPConnection,
    timeout: _ServerConnectionTimeout)
  =>
    _backend = backend
    _config = config
    _conn = conn
    _timeout = timeout
    _state = _HTTPServerConnectionState(backend, config, conn, _timeout)
    _parser = HTTP11RequestParser(_state)

  fun ref received(data: Array[U8] iso) =>
    // Let the parser take a look at what has been received.
    let res = _parser.parse(consume data)
    match res
    // Any syntax errors will terminate the connection.
    | let rpe: RequestParseError =>
      Debug("Parser: RPE")
      _conn.dispose()
    | NeedMore =>
      Debug("Parser: NeedMore")
    end

  fun ref closed() =>
    _backend.closed()
    _conn.unmute()

  fun ref throttled() =>
    _backend.throttled()

  fun ref unthrottled() =>
    _backend.unthrottled()

  fun ref _send_start(response: Response val, request_id: RequestID) =>
    _conn.unmute()

    // honor Connection: close header set by application
    match response.header("Connection")
    | "close" => _state.close_after = request_id
    end

    let expected_id = RequestIDs.next(_state.sent_response)
    if request_id == expected_id then
      // just send it through. all good
      _state.sent_response = request_id
      _timeout.reset()
      _conn.write(response.array())
    elseif RequestIDs.gt(request_id, expected_id) then
      // add serialized response to pending requests
      _state.pending_responses.add_pending(request_id, response.array())
    else
      // request_id < _active_request
      // latecomer - ignore
      None
    end

  fun ref _send_chunk(data: ByteSeq val, request_id: RequestID) =>
    if request_id == _state.sent_response then
      _timeout.reset()
      _conn.write(data)
    elseif RequestIDs.gt(request_id, _state.active_request) then
      _state.pending_responses.append_data(request_id, data)
    else
      None // latecomer, ignore
    end

  fun ref _send_finished(request_id: RequestID) =>
    // check if the next request_id is already in the pending list
    // if so, write it
    var rid = request_id
    while _state.pending_responses.has_pending() do
      match _state.pending_responses.pop(RequestIDs.next(rid))
      | (let next_rid: RequestID, let response_data: ByteSeqIter) =>
        //Debug("also sending next response for request: " + next_rid.string())
        rid = next_rid
        _state.sent_response = next_rid
        _timeout.reset()
        _conn.writev(response_data)
      else
        // next one not available yet
        break
      end
    end

    match _state.close_after
    | let close_after_me: RequestID if RequestIDs.gte(request_id, close_after_me) =>
      // only close after a request that requested it
      // in case of pipelining, we might receive a response for another, later
      // request earlier and would close prematurely.
      _conn.dispose()
    end

  fun ref _cancel(request_id: RequestID) =>
    if (_state.active_request - _state.sent_response) != 0 then
      // we still have some stuff in flight at the backend
      _backend.cancelled(request_id)
    end

  fun ref _send(response: Response val, body: ByteArrays, request_id: RequestID) =>
    _send_start(response, request_id)
    if request_id == _state.sent_response then
      _timeout.reset()
      _conn.writev(body.arrays())
      _send_finished(request_id)
    elseif RequestIDs.gt(request_id, _state.active_request) then

      _state.pending_responses.add_pending_arrays(
        request_id,
        body.arrays().>unshift(response.array())
      )
    else
      None // latecomer, ignore
    end

  fun ref _send_raw(raw: ByteSeqIter, request_id: RequestID, close_session: Bool = false) =>
    _conn.unmute()
    if close_session then
      // session will be closed when calling send_finished()
      _state.close_after = request_id
    end
    let expected_id = RequestIDs.next(_state.sent_response)
    if request_id == expected_id then
      _state.sent_response = request_id
      _timeout.reset()
      _conn.writev(raw)
    elseif RequestIDs.gt(request_id, expected_id) then
      //Debug("enqueing " + request_id.string() + ". Expected " + expected_id.string())
      _state.pending_responses.add_pending_arrays(request_id, raw)
    end


class _HTTPServerConnectionState is HTTP11RequestHandler
  let _backend: Handler
  let _config: ServerConfig
  let _conn: TCPConnection
  let _timeout: _ServerConnectionTimeout

  var close_after: (RequestID | None) = None

  var active_request: RequestID = RequestIDs.max_value()
    """
    keeps the request_id of the request currently active.
    That is, that has been sent to the backend last.
    """
  var sent_response: RequestID = RequestIDs.max_value()
    """
    Keeps track of the request_id for which we sent a response already
    in order to determine lag in request handling.
    """
  let pending_responses: _PendingResponses = _PendingResponses.create()

  new create(
    backend: Handler,
    config: ServerConfig,
    conn: TCPConnection,
    timeout: _ServerConnectionTimeout)
  =>
    _backend = backend
    _config = config
    _conn = conn
    _timeout = timeout

  fun ref _receive_start(request: Request val, request_id: RequestID) =>
    _timeout.reset()
    active_request = request_id
    // detemine if we need to close the connection after this request
    match (request.version(), request.header("Connection"))
    | (HTTP11, "close") =>
      close_after = request_id
    | (HTTP10, let connection_header: String) if connection_header != "Keep-Alive" =>
      close_after = request_id
    | (HTTP10, None) =>
      close_after = request_id
    end
    _backend(request, request_id)
    if pending_responses.size() >= _config.max_request_handling_lag then
      // Backpressure incoming requests if the queue grows too much.
      // The backpressure prevents filling up memory with queued
      // requests in the case of a runaway client.
      _conn.mute()
    end

  fun ref _receive_chunk(data: ByteSeq val, request_id: RequestID) =>
    """
    Receive some `request` body data, which we pass on to the handler.
    """
    _timeout.reset()
    _backend.chunk(data, request_id)

  fun ref _receive_finished(request_id: RequestID) =>
    """
    Indicates that the last *inbound* body chunk has been sent to
    `_chunk`. This is passed on to the back end.
    """
    _backend.finished(request_id)

  fun ref _receive_failed(parse_error: RequestParseError, request_id: RequestID) =>
    _backend.failed(parse_error, request_id)
    // TODO: close the connection?
