use "crypto"
use "encode/base64"
use "net"

use "http_server"
use ws = "websocket"

actor Main
  new create(env: Env) =>
    let host = "localhost"
    let port = "9999"
    let limit: USize = 9000
    let server = Server(
      TCPListenAuth(env.root),
      SimpleServerNotify,  // notify for server lifecycle events
      BackendMaker   // factory for session-based application backend
      where config = ServerConfig( // configuration of Server
        where host' = host,
              port' = port,
              max_concurrent_connections' = limit)
    )

class SimpleServerNotify
  fun ref listening(server: Server ref) =>
    None

  fun ref not_listening(server: Server ref) =>
    None

  fun ref closed(server: Server ref) =>
    None

class BackendMaker is HandlerFactory
  fun apply(session: Session): Handler^ =>
    RequestHandler.create(session)

class RequestHandler is Handler
  let _session: Session
  var _response_builder: ResponseBuilder

  new ref create(session: Session) =>
    _session = session
    _response_builder = Responses.builder()

  fun ref apply(request: Request val, request_id: RequestID) =>
    if (request.method() isnt GET) or (request.version() < HTTP11) then
      let body = "Invalid Method or HTTP version"
      this._send_err(request_id, StatusBadRequest, body)
    else 
      try
        let upgrade_header = request.header("Upgrade") as String
        if upgrade_header != "websocket" then
          error
        end
        let conn_header = request.header("Connection") as String
        if conn_header != "Upgrade" then
          error
        end
        // calculate Sec-Websocket-Accept from Sec-Websocket-Key
        let ws_key = request.header("Sec-WebSocket-Key") as String
        let sha1_digest = Digest.sha1()
        sha1_digest.append(ws_key)?
        sha1_digest.append("258EAFA5-E914-47DA-95CA-C5AB0DC85B11")?
        let hash: Array[U8] val = sha1_digest.final()
        let sec_ws_accept: String val = Base64.encode(hash)

        let ws_version = request.header("Sec-WebSocket-Version") as String
        if ws_version.u64()? != 13 then
          error
        end
        _session.send_raw(
          _response_builder.set_status(StatusSwitchingProtocols)
            .add_header("Upgrade", "websocket")
            .add_header("Connection", "Upgrade")
            .add_header("Sec-WebSocket-Accept", sec_ws_accept)
            .finish_headers()
            .build(),
          request_id
        )
        _session.send_finished(request_id)
        _session.upgrade(
          ws.WebsocketTCPConnectionNotify.open(
            MyLittleWebSocketConnectionNotify.create()
          )
        )
      else
        this._send_err(request_id, StatusBadRequest, "Invalid Websocket Handshake Request")
      end
    end

  fun ref chunk(data: ByteSeq val, request_id: RequestID) => None

  fun ref finished(request_id: RequestID) =>
    _response_builder = _response_builder.reset()

  fun ref _send_err(request_id: RequestID, status: Status, body: String) =>
    _session.send_raw(
      _response_builder.set_status(StatusBadRequest)
        .add_header("Server", "Pony/http_server")
        .add_header("Content-Length", body.size().string())
        .finish_headers()
        .add_chunk(body.array())
        .build(),
        request_id
    )
    _session.send_finished(request_id)

class iso MyLittleWebSocketConnectionNotify is ws.WebSocketConnectionNotify

  new iso create() => None

  fun ref opened(conn: ws.WebSocketConnection ref) =>
    None

  fun ref closed(conn: ws.WebSocketConnection ref) =>
    None

  fun ref text_received(conn: ws.WebSocketConnection ref, text: String) =>
    conn.send_text(text)

  fun ref binary_received(
    conn: ws.WebSocketConnection ref,
    data: Array[U8 val] val) =>
    conn.send_binary(data)
