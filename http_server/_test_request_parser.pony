use "debug"
use "itertools"
use "pony_test"
use "valbytes"

actor \nodoc\ _RequestParserTests is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_NoDataTest)
    test(_UnknownMethodTest)
    test(
      _ParserTestBuilder.parse_success(
        "simple",
        _R(
          """
          GET /url HTTP/1.1
          Connection: Close
          Content-Length: 2

          XX"""),
        {
          (h: TestHelper, request: Request, chunks: ByteArrays)? =>
            h.assert_eq[Method](GET, request.method())
            h.assert_eq[Version](HTTP11, request.version())
            h.assert_eq[String]("/url", request.uri().string())
            h.assert_eq[String]("Close", request.header("Connection") as String)
            h.assert_eq[USize](2, request.content_length() as USize)
            h.assert_eq[String]("2", request.header("Content-Length") as String)
            h.assert_eq[String]("XX", chunks.string())
            h.assert_true(request.has_body())
        }
      )
    )
    test(
      _ParserTestBuilder.parse_success(
        "no-headers",
        _R(
          """
          GET / HTTP/1.1

          """
        ),
        {
          (h: TestHelper, request: Request, chunks: ByteArrays) =>
            h.assert_eq[Method](GET, request.method())
            h.assert_eq[Version](HTTP11, request.version())
            h.assert_eq[String]("/", request.uri().string())
            h.assert_false(request.headers().has_next())
            h.assert_false(request.has_body())
        }
      )
    )
    test(
      _ParserTestBuilder.parse_success(
        "no-body",
        _R(
          """
          HEAD /upload?param=value HTTP/1.1
          Host: upload.org
          User-Agent: ponytest/0.33.1
          Accept: */*

          """
        ),
        {
          (h: TestHelper, request: Request, chunks: ByteArrays)? =>
            h.assert_eq[Method](HEAD, request.method())
            h.assert_eq[Version](HTTP11, request.version())
            h.assert_eq[String]("/upload?param=value", request.uri().string())
            h.assert_eq[String]("upload.org", request.header("Host") as String)
            h.assert_eq[String]("ponytest/0.33.1", request.header("user-agent") as String)
            h.assert_eq[String]("*/*", request.header("ACCEPT") as String)
            h.assert_true(request.content_length() is None)
            h.assert_eq[USize](0, chunks.size())
            h.assert_false(request.has_body())
        }
      )
    )
    test(_ParserTestBuilder.need_more("method", _R("""POS""")))
    test(_ParserTestBuilder.need_more("no-url", _R("""GET  """)))
    test(_ParserTestBuilder.need_more("url", _R("""GET   /""")))
    test(_ParserTestBuilder.need_more("http-version-1", _R("""GET   / HTTP/""")))
    test(_ParserTestBuilder.need_more("request-line", _R("""GET   / HTTP/1.1""")))
    test(_ParserTestBuilder.need_more("no-headers",
        _R(
          """
          GET   / HTTP/1.1
          """)
    ))
    test(_ParserTestBuilder.need_more("header-name",
        _R(
          """
          GET   / HTTP/1.1
          Header""")
    ))
    test(_ParserTestBuilder.need_more("header-sep",
        _R(
          """
          GET   / HTTP/1.1
          Header:""")
    ))
    test(_ParserTestBuilder.need_more("header-sep-ws",
        _R(
          """
          GET   / HTTP/1.1
          Header:  """)
    ))
    test(_ParserTestBuilder.need_more("header",
        _R(
          """
          GET   / HTTP/1.1
          Header:  Value""")
    ))
    test(_ParserTestBuilder.need_more("header-multi-line",
        _R(
          """
          GET   / HTTP/1.1
          Header:  Value
           MultiLine""")
    ))
    test(_ParserTestBuilder.need_more("header-eoh",
        _R(
          """
          GET   / HTTP/1.1
          Header:  Value
           MultiLine
          Header2: Foo
          """)
    ))
    test(_ParserTestBuilder.need_more("body",
        _R(
          """
          GET   / HTTP/1.1
          Content-Length:  1

          """)
        where ok_to_finish = true
    ))
    test(_ParserTestBuilder.need_more("body-2",
        _R(
          """
          GET   / HTTP/1.1
          Content-Length:  2

          X""")
        where ok_to_finish = true
    ))
    test(_ParserTestBuilder.need_more("chunk-start",
        _R(
          """
          GET   / HTTP/1.1
          Transfer-Encoding: chunked

          A""")
        where ok_to_finish = true)
    )
    test(_ParserTestBuilder.need_more("chunk-start-extension",
        _R(
          """
          GET   / HTTP/1.1
          Transfer-Encoding: chunked

          A;bla=blubb""")
        where ok_to_finish = true)
    )
    test(_ParserTestBuilder.need_more("chunk",
        _R(
          """
          GET   / HTTP/1.1
          Transfer-Encoding: chunked

          A;bla=blubb
          012345678""")
        where ok_to_finish = true)
    )
    test(_ParserTestBuilder.need_more("chunk-full",
        _R(
          """
          GET   / HTTP/1.1
          Transfer-Encoding: chunked

          A;bla=blubb
          0123456789""")
        where ok_to_finish = true
      )
    )
    test(_ParserTestBuilder.need_more("chunk-end",
        _R(
          """
          GET   / HTTP/1.1
          Transfer-Encoding: chunked

          A;bla=blubb
          0123456789
          """)
        where ok_to_finish = true)
    )
    test(_ParserTestBuilder.need_more("chunk-last",
        _R(
          """
          GET   / HTTP/1.1
          Transfer-Encoding: chunked

          A;bla=blubb
          0123456789
          0
          """)
        where ok_to_finish = true)
    )

primitive \nodoc\ _R
  fun apply(s: String): String =>
    "\r\n".join(
      Iter[String](s.split_by("\n").values())
        .map[String]({(s) => s.clone().>strip("\r") })
    )

actor \nodoc\ _MockRequestHandler is HTTP11RequestHandler
  be _receive_start(request: Request val, request_id: RequestID) =>
    Debug("_receive_start: " + request_id.string())

  be _receive_chunk(data: Array[U8] val, request_id: RequestID) =>
    Debug("_receive_chunk: " + request_id.string())

  be _receive_finished(request_id: RequestID) =>
    Debug("_receive_finished: " + request_id.string())

  be _receive_failed(parse_error: RequestParseError, request_id: RequestID) =>
    Debug("_receive_failed: " + request_id.string())

primitive \nodoc\ _ParserTestBuilder
  fun parse_success(
    name': String,
    request': String,
    callback: {(TestHelper, Request val, ByteArrays)? } val)
    : UnitTest iso^
  =>
    object iso is UnitTest
      let cb: {(TestHelper, Request val, ByteArrays)? } val = callback
      let req_str: String = request'
      fun name(): String => "request_parser/success/" + name'
      fun apply(h: TestHelper) =>
        h.long_test(1_000_000_000)
        let parser = HTTP11RequestParser(
          object is HTTP11RequestHandler
            var req: (Request | None) = None
            var chunks: ByteArrays = ByteArrays
            be _receive_start(request: Request val, request_id: RequestID) =>
              h.log("received request")
              req = request

            be _receive_chunk(data: Array[U8] val, request_id: RequestID) =>
              h.log("received chunk")
              chunks = chunks + data

            be _receive_finished(request_id: RequestID) =>
              h.log("received finished")
              try
                cb(h, req as Request, chunks)?
                h.complete(true)
              else
                h.complete(false)
                h.fail("callback failed.")
              end
              chunks = ByteArrays
              req = None

            be _receive_failed(parse_error: RequestParseError, request_id: RequestID) =>
              h.complete(false)
              h.fail("FAILED WITH " + parse_error.string() + " FOR REQUEST:\n\n" + req_str)
          end
        )
        h.assert_eq[String]("None", parser.parse(_ArrayHelpers.iso_array(req_str)).string())
    end

  fun need_more(name': String, request': String, ok_to_finish: Bool = false): UnitTest iso^ =>
    object iso is UnitTest
      let req_str: String = request'
      let ok_to_finish': Bool = ok_to_finish
      fun name(): String => "request_parser/need_more/" + name'
      fun apply(h: TestHelper) =>
        let parser = HTTP11RequestParser(
          object is HTTP11RequestHandler
            be _receive_start(request: Request val, request_id: RequestID) =>
              h.log("receive_start")
            be _receive_chunk(data: Array[U8] val, request_id: RequestID) =>
              h.log("received chunk of size: " + data.size().string())

            be _receive_finished(request_id: RequestID) =>
              if not ok_to_finish' then
                h.fail("didnt expect this request to finish:\n\n" + req_str)
              end

            be _receive_failed(parse_error: RequestParseError, request_id: RequestID) =>
              h.fail("FAILED WITH " + parse_error.string() + " FOR REQUEST:\n\n" + req_str)
          end
        )
        h.assert_eq[String]("NeedMore", parser.parse(_ArrayHelpers.iso_array(req_str)).string())
    end

class \nodoc\ iso _NoDataTest is UnitTest
  fun name(): String => "request_parser/no_data"
  fun apply(h: TestHelper) =>
    let parser = HTTP11RequestParser(
      object is HTTP11RequestHandler
        be _receive_start(request: Request val, request_id: RequestID) =>
          h.fail("request delivered from no data.")
        be _receive_chunk(data: Array[U8] val, request_id: RequestID) =>
          h.fail("chunk delivered from no data.")
        be _receive_finished(request_id: RequestID) =>
          h.fail("finished called from no data.")
        be _receive_failed(parse_error: RequestParseError, request_id: RequestID) =>
          h.fail("failed called from no data.")
      end
    )
    h.assert_is[ParseReturn](NeedMore, parser.parse(recover Array[U8](0) end))

class \nodoc\ iso _UnknownMethodTest is UnitTest
  fun name(): String => "request_parser/unknown_method"
  fun apply(h: TestHelper) =>
    let parser = HTTP11RequestParser(
      object is HTTP11RequestHandler
        be _receive_start(request: Request val, request_id: RequestID) =>
          h.fail("request delivered from no data.")
        be _receive_chunk(data: Array[U8] val, request_id: RequestID) =>
          h.fail("chunk delivered from no data.")
        be _receive_finished(request_id: RequestID) =>
          h.fail("finished called from no data.")
        be _receive_failed(parse_error: RequestParseError, request_id: RequestID) =>
          h.assert_is[RequestParseError](UnknownMethod, parse_error)
      end
    )
    h.assert_is[ParseReturn](
      UnknownMethod,
      parser.parse(_ArrayHelpers.iso_array("ABC /"))
    )

primitive \nodoc\ _ArrayHelpers
  fun tag iso_array(s: String): Array[U8] iso^ =>
    (recover iso String(s.size()).>append(s) end).iso_array()
