use "pony_test"

actor \nodoc\ _ResponseTests is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_BuildableResponseTest)

class \nodoc\ iso _BuildableResponseTest is UnitTest
  fun name(): String => "responses/BuildableResponse"

  fun apply(h: TestHelper) ? =>
    let without_length = BuildableResponse()
    h.assert_is[None](None, without_length.header("Content-Length") as None)

    let with_length = BuildableResponse(where content_length' = 42)
    h.assert_eq[String]("42", with_length.header("Content-Length") as String)
