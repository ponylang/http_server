use "debug"
use "pony_check"
use "pony_test"
use "valbytes"

actor \nodoc\ _HeaderTests is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(Property1UnitTest[Array[Header]](_HeadersGetProperty))

class \nodoc\ iso _HeadersGetProperty is Property1[Array[Header]]
  fun name(): String => "headers/get/property"

  fun gen(): Generator[Array[Header]] =>
    let name_gen = Generators.ascii_letters(where max=10)
    let value_gen = Generators.ascii_letters(where max=10)
    Generators.array_of[Header](
      Generators.zip2[String, String](
        name_gen,
        value_gen
      )
    )

  fun property(sample: Array[Header], h: PropertyHelper) =>
    let headers = Headers.create()
    let added: Array[Header] = Array[Header](sample.size())
    for header in sample.values() do
      headers.add(header._1, header._2)
      added.push(header)
      for added_header in added.values() do
        match headers.get(added_header._1.upper())
        | None => h.fail("not found " + added_header._1)
        | let s: String =>
          var found = false
          for splitted in s.split(",").values() do
            if added_header._2 == splitted then
              found = true
              break
            end
          end
          if not found then
            h.assert_eq[String](added_header._2, s)
          end
        end
      end
    end
