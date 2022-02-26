use "files"
use "net"
use "net_ssl"
use "pony_test"

actor \nodoc\ _ServerErrorHandlingTests is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_ServerConnectionClosedTest)

class \nodoc\ val _ServerConnectionClosedHandlerFactory is HandlerFactory
  let _h: TestHelper
  new val create(h: TestHelper) =>
    _h = h

  fun apply(session: Session): Handler ref^ =>
    object is Handler
      fun ref apply(res: Request val, request_id: RequestID) =>
        _h.log("received request")
      fun ref closed() =>
        _h.complete_action("server failed with ConnectionClosed")
    end

class \nodoc\ iso _ServerConnectionClosedTest is UnitTest
  fun name(): String => "server/error-handling/connection-closed"
  fun apply(h: TestHelper) =>
    h.long_test(5_000_000_000)
    h.expect_action("server listening")
    h.expect_action("client connected")
    h.expect_action("server failed with ConnectionClosed")

    let server = Server(
      TCPListenAuth(h.env.root),
      object iso is ServerNotify
        let _h: TestHelper = h
        fun ref listening(server: Server ref) =>
          _h.complete_action("server listening")

          try
            (let host, let port) = server.local_address().name()?
            _h.log("listening on " + host + ":" + port)
            let conn =
              TCPConnection(
                TCPConnectAuth(_h.env.root),
                object iso is TCPConnectionNotify
                  fun ref connected(conn: TCPConnection ref) =>
                    _h.complete_action("client connected")
                    conn.write("GET /abc/def HTTP/1.1\r\n\r\n")
                    conn.dispose()

                  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
                    true

                  fun ref connect_failed(conn: TCPConnection ref) =>
                    _h.fail("client connect failed")

                  fun ref closed(conn: TCPConnection ref) =>
                    _h.complete_action("client connection closed")
                end,
                host,
                port)
            _h.dispose_when_done(conn)

          else
            _h.fail("error starting client")
          end

        fun ref not_listening(server: Server ref) =>
          _h.fail_action("server listening")

        fun ref closed(server: Server ref) =>
          _h.log("server stopped listening")
      end,
      _ServerConnectionClosedHandlerFactory(h)
      where config = ServerConfig(where host'="127.0.0.1")
    )
    h.dispose_when_done(server)
