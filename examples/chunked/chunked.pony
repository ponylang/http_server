use "../../http_server"
use "net"
use "valbytes"
use "debug"

actor Main
  """
  A simple example of how to send your response body gradually. When sending
  large responses you don't want the entire payload in memory at the same
  time.
  """
  new create(env: Env) =>
    for arg in env.args.values() do
      if (arg == "-h") or (arg == "--help") then
        _print_help(env)
        return
      end
    end

    let port = try env.args(1)? else "50000" end
    let limit = try env.args(2)?.usize()? else 100 end
    let host = "localhost"

    // Start the top server control actor.
    let server = Server(
      TCPListenAuth(env.root),
      LoggingServerNotify(env),  // notify for server lifecycle events
      BackendMaker.create(env)   // factory for session-based application backend
      where config = ServerConfig( // configuration of Server
        where host' = host,
              port' = port,
              max_concurrent_connections' = limit)
    )
    // everything is initialized, if all goes well
    // the server is listening on the given port
    // and thus kept alive by the runtime, as long its listening socket is not
    // closed.

  fun _print_help(env: Env) =>
    env.err.print(
      """
      Usage:

         chunked [<PORT> = 50000] [<MAX_CONCURRENT_CONNECTIONS> = 100]

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

  new val create(env: Env) =>
    _env = env

  fun apply(session: Session): Handler^ =>
    BackendHandler.create(_env, session)

class BackendHandler is Handler
  """
  Backend application instance for a single HTTP session.

  Executed on an actor representing the HTTP Session.
  That means we have 1 actor per TCP Connection
  (to be exact it is 2 as the TCPConnection is also an actor).
  """
  let _env: Env
  let _session: Session

  var _response: BuildableResponse
  var stage: (ExHdrs | ExHello | ExWorld) = ExHdrs

  new ref create(env: Env, session: Session) =>
    _env = env
    _session = session
    _response = BuildableResponse(where status' = StatusOK)

  fun ref finished(request_id: RequestID): Bool =>
    """
    Start processing a request.

    Called when request-line and all headers have been parsed.
    Body is not yet parsed, not even received maybe.

    In this example we have a simple State Machine which we
    use to demonstrate how replies can be chunked in such a
    way as we trade memory efficiency for speed.

    This tradeoff is needed when sending huge files.

    """

    match stage
    | ExHdrs =>
      var response: BuildableResponse iso = BuildableResponse(where status' = StatusOK)
      response.add_header("Content-Type", "text/plain")
      response.add_header("Server", "http_server.pony/0.2.1")
      response.add_header("Content-Length", "12")

      _session.send_start(consume response, request_id)
      stage = ExHello
      return false
    | ExHello => _session.send_chunk("Hello ", request_id)
      stage = ExWorld
      return false
    | ExWorld =>
      _session.send_chunk("World!", request_id)
      _session.send_finished(request_id)
      stage = ExHdrs
      return true
    end
    true // Never Reached

primitive ExHdrs
primitive ExHello
primitive ExWorld
