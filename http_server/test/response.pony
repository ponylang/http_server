use "ponytest"
use ".."

primitive ResponseTests is TestList
  fun tag tests(test: PonyTest) =>
    test(BuildableResponseTest)

class iso BuildableResponseTest is UnitTest
  fun name(): String => "responses/BuildableResponse"

  fun apply(h: TestHelper) ? =>
    let without_length = BuildableResponse()
    h.assert_is[None](None, without_length.header("Content-Length") as None)

    let with_length = BuildableResponse(where content_length' = 42)
    h.assert_eq[String]("42", with_length.header("Content-Length") as String)
