use "../../http_server"

use "files"
use "format"
use "net"

actor Main
  """
  Serve a single file over HTTP, possiblky chunked if it exceeds 4096 bytes (arbitrary choice just for this example).
  """
  new create(env: Env) =>
    for arg in env.args.values() do
      if (arg == "-h") or (arg == "--help") then
        _print_help(env)
        return
      end
    end

    var file =
      try
        let path = env.args(1)?
        FilePath(FileAuth(env.root), path)
      else
        env.err.print("Missing file argument")
        _print_help(env)
        env.exitcode(1)
        return
      end
    // resolve file
    file = try
      file.canonical()?
    else
      env.err.print(file.path + " does not exist or is not readable")
      env.exitcode(1)
      return
    end
    // get file size - we simply assume it doesn't change/grow
    let file_size = 
      match OpenFile(file)
      | let f: File =>
        let s = f.size()
        f.dispose()
        s
      else
        env.err.print("Error opening"  + file.path)
        env.exitcode(1)
        return
      end

    // Start the top server control actor.
    let server = Server(
      TCPListenAuth(env.root),
      LoggingServerNotify(env),  // notify for server lifecycle events
      BackendMaker.create(env, file, file_size)   // factory for session-based application backend
      where config = ServerConfig( // configuration of Server
        where host' = "localhost",
              port' = "65535",
              max_concurrent_connections' = 65535)
    )
    // everything is initialized, if all goes well
    // the server is listening on the given port
    // and thus kept alive by the runtime, as long its listening socket is not
    // closed.

  fun _print_help(env: Env) =>
    env.err.print(
      """
      Usage:

         handle_file <FILE>

      """
    )

class LoggingServerNotify is ServerNotify
  """
  Notification class that is notified about
  important lifecycle events for the Server
  """
  let _env: Env

  new iso create(env: Env) =>
    _env = env

  fun ref listening(server: Server ref) =>
    """
    Called when the Server starts listening on its host:port pair via TCP.
    """
    try
      (let host, let service) = server.local_address().name()?
      _env.err.print("connected: " + host + ":" + service)
    else
      _env.err.print("Couldn't get local address.")
      _env.exitcode(1)
      server.dispose()
    end

  fun ref not_listening(server: Server ref) =>
    """
    Called when the Server was not able to start listening on its host:port pair via TCP.
    """
    _env.err.print("Failed to listen.")
    _env.exitcode(1)

  fun ref closed(server: Server ref) =>
    """
    Called when the Server is closed.
    """
    _env.err.print("Shutdown.")

class BackendMaker is HandlerFactory
  """
  Fatory to instantiate a new HTTP-session-scoped backend instance.
  """
  let _env: Env
  let _file_path: FilePath
  let _file_size: USize

  new val create(env: Env, file_path: FilePath, file_size: USize) =>
    _env = env
    _file_path = file_path
    _file_size = file_size

  fun apply(session: Session): Handler^ =>
    BackendHandler.create(_env, session, _file_path, _file_size)

class BackendHandler is Handler
  """
  Backend application instance for a single HTTP session.

  Executed on an actor representing the HTTP Session.
  That means we have 1 actor per TCP Connection
  (to be exact it is 2 as the TCPConnection is also an actor).
  """
  let _env: Env
  let _session: Session
  let _file: (File | None)
  let _file_size: USize
  let _content_type: String
  let _chunked: (Chunked | None)

  var _current: (Request | None) = None

  new ref create(env: Env, session: Session, file_path: FilePath, file_size: USize) =>
    _env = env
    _session = session
    _content_type = MimeTypes(file_path.path)
    _file =
      try
        OpenFile(file_path) as File
      end
    _file_size = file_size
    _chunked = if file_size > 4096 then Chunked else None end

  fun ref apply(request: Request val, request_id: RequestID) =>
    _current = request

  fun ref chunk(data: ByteSeq val, request_id: RequestID) =>
    // ignore request body
    None

  fun ref finished(request_id: RequestID) =>
    match (_current, _file)
    | (let request: Request, let file: File) =>
      if request.method() == GET then
        match _chunked
        | Chunked =>
          _send_chunked_response(file, request_id)
        | None =>
          _send_oneshot_response(file, request_id)
        end
      else
        let msg = "only GET is allowed"
        _session.send_raw(
          Responses.builder().set_status(StatusMethodNotAllowed)
            .add_header("Content-Type", "text/plain")
            .set_content_length(msg.size())
            .finish_headers()
            .add_chunk(msg)
            .build(),
          request_id
        )
        _session.send_finished(request_id)
      end
    else
      let msg = "Error opening file"
      _session.send_raw(
        Responses.builder().set_status(StatusInternalServerError)
          .add_header("Content-Type", "text/plain")
          .set_content_length(msg.size())
          .finish_headers()
          .add_chunk(msg)
          .build(),
        request_id
      )
      _session.send_finished(request_id)
    end
    _current = None

  fun ref _send_chunked_response(file: File, request_id: RequestID) =>
    let response = BuildableResponse
    response.set_transfer_encoding(_chunked)
    response.set_header("Content-Type", _content_type)
    _session.send_start(consume response, request_id)
    // move to start
    file.seek_start(0)

    let chunk_size = USize(8192) // arbitrary choice

    let crlf = recover val [as U8: '\r'; '\n'] end
    while true do
      let file_chunk = file.read(chunk_size)
      if file_chunk.size() == 0 then
        // send last chunk
        let last_chunk = (recover val Format.int[USize](0 where fmt = FormatHexBare).>append(crlf).>append(crlf) end).array()
        _session.send_chunk(last_chunk, request_id)
        // finish sending
        _session.send_finished(request_id)
        break
      else
        // manually form a chunk
        let chunk_prefix = (recover val Format.int[USize](file_chunk.size() where fmt = FormatHexBare).>append(crlf) end).array()
        _session.send_chunk(chunk_prefix, request_id)
        _session.send_chunk(consume file_chunk, request_id)
        _session.send_chunk(crlf, request_id)
      end
    end

  fun ref _send_oneshot_response(file: File, request_id: RequestID) =>
    let response = BuildableResponse
    response.set_content_length(_file_size)
    response.set_header("Content-Type", _content_type)
    _session.send_start(consume response, request_id)
    // move to start
    file.seek_start(0)

    var read = USize(0)
    while read < _file_size do
      let file_chunk = file.read(_file_size - read)
      read = read + file_chunk.size()
      if file_chunk.size() == 0 then
        _session.send_finished(request_id)
        break
      else
        _session.send_chunk(consume file_chunk, request_id)
      end
    end
