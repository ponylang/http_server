use "pony_test"
use "net"
use "time"

actor \nodoc\ _ConnectionHandlingTests is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_ConnectionTimeoutTest)
    test(_ConnectionCloseHeaderTest)
    test(_ConnectionHTTP10Test)
    test(_ConnectionHTTP10DefaultCloseTest)
    test(_ConnectionCloseHeaderResponseTest)
    test(_ConnectionCloseHeaderRawResponseTest)

class \nodoc\ val _ClosedTestHandlerFactory is HandlerFactory
  let _h: TestHelper

  new val create(h: TestHelper) =>
    _h = h

  fun apply(session: Session): Handler ref^ =>
    object ref is Handler
      fun ref apply(request: Request val, request_id: RequestID) =>
        _h.complete_action("request-received")

        // send response
        session.send_raw(
          Responses.builder()
            .set_status(StatusOK)
            .add_header("Content-Length", "0")
            .finish_headers()
            .build(),
          request_id
        )
        session.send_finished(request_id)

      fun ref closed() =>
        _h.complete_action("connection-closed")
    end


class \nodoc\ iso _ConnectionTimeoutTest is UnitTest
  """
  test that connection is closed when `connection_timeout` is set to `> 0`.
  """
  fun name(): String => "connection/timeout"

  fun apply(h: TestHelper) =>
    h.long_test(Nanos.from_seconds(5))
    h.expect_action("request-received")
    h.expect_action("connection-closed")
    h.dispose_when_done(
      Server(
        TCPListenAuth(h.env.root),
        object iso is ServerNotify
          fun ref listening(server: Server ref) =>
            try
              (let host, let port) = server.local_address().name()?
              h.log("listening on " + host + ":" + port)
              TCPConnection(
                TCPConnectAuth(h.env.root),
                object iso is TCPConnectionNotify
                  fun ref connected(conn: TCPConnection ref) =>
                    conn.write("GET / HTTP/1.1\r\nContent-Length: 0\r\n\r\n")
                  fun ref connect_failed(conn: TCPConnection ref) =>
                    h.fail("connect failed")
                end,
                host,
                port
              )
            end
          fun ref closed(server: Server ref) =>
            h.fail("closed")
        end,
        _ClosedTestHandlerFactory(h),
        ServerConfig(
          where connection_timeout' = 1,
                timeout_heartbeat_interval' = 500
        )
      )
    )

class \nodoc\ iso _ConnectionCloseHeaderTest is UnitTest
  """
  test that connection is closed when 'Connection: close' header
  was sent, even if we didn't specify a timeout.
  """

  fun name(): String => "connection/connection_close_header"

  fun apply(h: TestHelper) =>
    h.long_test(Nanos.from_seconds(5))
    h.expect_action("request-received")
    h.expect_action("connection-closed")
    h.dispose_when_done(
      Server(
        TCPListenAuth(h.env.root),
        object iso is ServerNotify
          fun ref listening(server: Server ref) =>
            try
              (let host, let port) = server.local_address().name()?
              h.log("listening on " + host + ":" + port)
              TCPConnection(
                TCPConnectAuth(h.env.root),
                object iso is TCPConnectionNotify
                  fun ref connected(conn: TCPConnection ref) =>
                    conn.write("GET / HTTP/1.1\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
                  fun ref connect_failed(conn: TCPConnection ref) =>
                    h.fail("connect failed")
                end,
                host,
                port
              )
            end
          fun ref closed(server: Server ref) =>
            h.fail("closed")
        end,
        _ClosedTestHandlerFactory(h),
        ServerConfig()
      )
    )

class \nodoc\ iso _ConnectionCloseHeaderResponseTest is UnitTest
  """
  test that connection is closed when the application returned a 'Connection: close'
  header.
  """
  fun name(): String => "connection/connection_close_response"

  fun apply(h: TestHelper) =>
    h.long_test(Nanos.from_seconds(5))
    h.expect_action("request-received")
    h.expect_action("connection-closed")
    h.dispose_when_done(
      Server(
        TCPListenAuth(h.env.root),
        object iso is ServerNotify
          fun ref listening(server: Server ref) =>
            try
              (let host, let port) = server.local_address().name()?
              h.log("listening on " + host + ":" + port)
              TCPConnection(
                TCPConnectAuth(h.env.root),
                object iso is TCPConnectionNotify
                  fun ref connected(conn: TCPConnection ref) =>
                    conn.write("GET / HTTP/1.1\r\nContent-Length: 0\r\n\r\n")
                  fun ref connect_failed(conn: TCPConnection ref) =>
                    h.fail("connect failed")
                end,
                host,
                port
              )
            end
          fun ref closed(server: Server ref) =>
            h.fail("closed")
        end,
        {(session)(h): Handler ref^ =>
          object ref is Handler
            fun ref apply(request: Request val, request_id: RequestID) =>
              h.complete_action("request-received")
              let res = BuildableResponse(where status' = StatusOK)
              res.add_header("Connection", "close")
              res.set_content_length(0)
              session.send_start(consume res, request_id)
              session.send_finished(request_id)

            fun ref closed() =>
              h.complete_action("connection-closed")
          end
        },
        ServerConfig()
      )
    )

class \nodoc\ iso _ConnectionCloseHeaderRawResponseTest is UnitTest
  fun name(): String => "connection/connection_close_raw_response"

  fun apply(h: TestHelper) =>
    h.long_test(Nanos.from_seconds(5))
    h.expect_action("request-received")
    h.expect_action("connection-closed")
    h.dispose_when_done(
      Server(
        TCPListenAuth(h.env.root),
        object iso is ServerNotify
          fun ref listening(server: Server ref) =>
            try
              (let host, let port) = server.local_address().name()?
              h.log("listening on " + host + ":" + port)
              TCPConnection(
                TCPConnectAuth(h.env.root),
                object iso is TCPConnectionNotify
                  fun ref connected(conn: TCPConnection ref) =>
                    conn.write("GET / HTTP/1.1\r\nContent-Length: 0\r\n\r\n")
                  fun ref connect_failed(conn: TCPConnection ref) =>
                    h.fail("connect failed")
                end,
                host,
                port
              )
            end
          fun ref closed(server: Server ref) =>
            h.fail("closed")
        end,
        {(session)(h): Handler ref^ =>
          object ref is Handler
            fun ref apply(request: Request val, request_id: RequestID) =>
              h.complete_action("request-received")
              session.send_raw(
                Responses.builder()
                  .set_status(StatusOK)
                  .add_header("Connection", "close")
                  .add_header("Content-Length", "0")
                  .finish_headers()
                  .build(),
                request_id
                where close_session = true)
              session.send_finished(request_id)

            fun ref closed() =>
              h.complete_action("connection-closed")
          end
        },
        ServerConfig()
      )
    )

class \nodoc\ iso _ConnectionHTTP10Test is UnitTest
  """
  test that connection is closed when HTTP version is 1.0
  and no 'Connection: keep-alive' is given.
  """
  fun name(): String => "connection/http10/no_keep_alive"

  fun apply(h: TestHelper) =>
    h.long_test(Nanos.from_seconds(5))
    h.expect_action("request-received")
    h.expect_action("connection-closed")
    h.dispose_when_done(
      Server(
        TCPListenAuth(h.env.root),
        object iso is ServerNotify
          fun ref listening(server: Server ref) =>
            try
              (let host, let port) = server.local_address().name()?
              h.log("listening on " + host + ":" + port)
              TCPConnection(
                TCPConnectAuth(h.env.root),
                object iso is TCPConnectionNotify
                  fun ref connected(conn: TCPConnection ref) =>
                    conn.write("GET / HTTP/1.0\r\nContent-Length: 0\r\nConnection: blaaa\r\n\r\n")
                  fun ref connect_failed(conn: TCPConnection ref) =>
                    h.fail("connect failed")
                end,
                host,
                port
              )
            end
          fun ref closed(server: Server ref) =>
            h.fail("closed")
        end,
        _ClosedTestHandlerFactory(h),
        ServerConfig()
      )
    )

class \nodoc\ iso _ConnectionHTTP10DefaultCloseTest is UnitTest
  """
  Test that connection is closed when HTTP version is 1.0
  and not "Connection" header is given.
  """
  fun name(): String => "connection/http10/no_connection_header"

  fun apply(h: TestHelper) =>
    h.long_test(Nanos.from_seconds(5))
    h.expect_action("request-received")
    h.expect_action("connection-closed")
    h.dispose_when_done(
      Server(
        TCPListenAuth(h.env.root),
        object iso is ServerNotify
          fun ref listening(server: Server ref) =>
            try
              (let host, let port) = server.local_address().name()?
              h.log("listening on " + host + ":" + port)
              TCPConnection(
                TCPConnectAuth(h.env.root),
                object iso is TCPConnectionNotify
                  fun ref connected(conn: TCPConnection ref) =>
                    conn.write("GET / HTTP/1.0\r\nContent-Length: 0\r\n\r\n")
                  fun ref connect_failed(conn: TCPConnection ref) =>
                    h.fail("connect failed")
                end,
                host,
                port
              )
            end
          fun ref closed(server: Server ref) =>
            h.fail("closed")
        end,
        _ClosedTestHandlerFactory(h),
        ServerConfig()
      )
    )
