use "pony_test"

actor \nodoc\ _ResponseTests is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_BuildableResponseTest)

class \nodoc\ iso _BuildableResponseTest is UnitTest
fun name(): String => "responses/BuildableResponse"

  fun apply(h: TestHelper) =>
    let without_length = BuildableResponse()
    h.assert_true(without_length.header("Content-Length") is None, "Content-Length header set although not provided in constructor")

    let array = recover val String.from_iso_array(without_length.array()) end
    h.log(array)
    h.assert_true(array.contains("Content-Length: 0\r\n"), "No content-length header added in array response")

    let bytes = without_length.to_bytes().string()
    h.log(bytes)
    h.assert_true(bytes.contains("Content-Length: 0\r\n"), "No content-length header added in to_bytes response")

    
    let with_length = BuildableResponse().set_content_length(42)
    match with_length.header("Content-Length")
    | let hvalue: String =>
      h.assert_eq[String]("42", hvalue)
    | None =>
      h.fail("No Content-Length header set")
    end

    let chunked_without_length = BuildableResponse().set_transfer_coding(Chunked)
    h.assert_true(without_length.header("Content-Length") is None, "Content-Length header set although not provided in constructor")

    let array2 = recover val String.from_iso_array(chunked_without_length.array()) end
    h.log(array2)
    h.assert_false(array2.contains("Content-Length: "), "Content-length header added in array response although chunked")

    let bytes2 = chunked_without_length.to_bytes().string()
    h.log(bytes2)
    h.assert_false(bytes2.contains("Content-Length: "), "Content-length header added in to_bytes response although chunked")

    // first set content-length, then transfer coding
    let complex =
      BuildableResponse().set_content_length(42).set_transfer_coding(Chunked)
    h.assert_true(complex.header("Content-Length") is None, "Content-Length header set although not provided in constructor")

    let array3 = recover val String.from_iso_array(complex.array()) end
    h.log(array3)
    h.assert_false(array3.contains("Content-Length: "), "Content-length header added in array response although chunked")

    let bytes3 = complex.to_bytes().string()
    h.log(bytes3)
    h.assert_false(bytes3.contains("Content-Length: "), "Content-length header added in to_bytes response although chunked")



