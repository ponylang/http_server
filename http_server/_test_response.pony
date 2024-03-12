use "pony_test"

actor \nodoc\ _ResponseTests is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_BuildableResponseTest)
    test(_ResponseBuilderTest)

class \nodoc\ iso _BuildableResponseTest is UnitTest
  fun name(): String => "responses/BuildableResponse"

  fun apply(h: TestHelper) =>
    let without_length = BuildableResponse()
    h.assert_true(without_length.header("Content-Length") is None, "Content-Length header set although not provided in constructor")

    let array = recover val String.from_iso_array(without_length.array()) end
    h.log(array)
    h.assert_true(array.contains("\r\nContent-Length: 0\r\n"), "No content-length header added in array response")

    let bytes = without_length.to_bytes().string()
    h.log(bytes)
    h.assert_true(bytes.contains("\r\nContent-Length: 0\r\n"), "No content-length header added in to_bytes response")

    
    let with_length = BuildableResponse().set_content_length(42)
    match with_length.header("Content-Length")
    | let hvalue: String =>
      h.assert_eq[String]("42", hvalue)
    | None =>
      h.fail("No Content-Length header set")
    end

    let chunked_without_length = BuildableResponse().set_transfer_encoding(Chunked)
    h.assert_true(without_length.header("Content-Length") is None, "Content-Length header set although not provided in constructor")

    let array2 = recover val String.from_iso_array(chunked_without_length.array()) end
    h.log(array2)
    h.assert_false(array2.contains("\r\nContent-Length: "), "Content-length header added in array response although chunked")

    let bytes2 = chunked_without_length.to_bytes().string()
    h.log(bytes2)
    h.assert_false(bytes2.contains("\r\nContent-Length: "), "Content-length header added in to_bytes response although chunked")

    // first set content-length, then transfer coding
    let complex =
      BuildableResponse().set_content_length(42).set_transfer_encoding(Chunked)
    h.assert_true(complex.header("Content-Length") is None, "Content-Length header set although not provided in constructor")

    let array3 = recover val String.from_iso_array(complex.array()) end
    h.log(array3)
    h.assert_false(array3.contains("\r\nContent-Length: "), "Content-length header added in array response although chunked")

    let bytes3 = complex.to_bytes().string()
    h.log(bytes3)
    h.assert_false(bytes3.contains("\r\nContent-Length: "), "Content-length header added in to_bytes response although chunked")


class \nodoc\ iso _ResponseBuilderTest is UnitTest
  fun name(): String => "responses/ResponseBuilder"

  fun apply(h: TestHelper) =>
    let without_length = Responses.builder().set_status(StatusOK).add_header("Server", "FooBar").finish_headers().build()
    var s = String.create()
    for bs in without_length.values() do
      s.append(bs)
    end
    h.assert_true(s.contains("\r\nContent-Length: 0\r\n"), "No content length added to Request: " + s)

    let with_length = Responses.builder().set_status(StatusOK).set_content_length(4).finish_headers().add_chunk("COOL").build()
    s = String.create()
    for bs in with_length.values() do
      s.append(bs)
    end
    h.assert_true(s.contains("\r\nContent-Length: 4\r\n"), "No or wrong content length added to Request: " + s)

    let chunked =
      Responses.builder().set_status(StatusOK).set_transfer_encoding(Chunked).add_header("Foo", "Bar").finish_headers().add_chunk("FOO").add_chunk("BAR").add_chunk("").build()
    let c = recover val
      let tmp = String.create()
      for bs in chunked.values() do
        tmp.append(bs)
      end
      tmp
    end
    h.assert_eq[String]("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nFoo: Bar\r\n\r\n3\r\nFOO\r\n3\r\nBAR\r\n0\r\n\r\n", c)
