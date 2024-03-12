use "collections"
use "debug"
use "pony_check"
use "pony_test"
use "valbytes"

actor \nodoc\ _HeaderTests is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(Property1UnitTest[Array[Header]](_HeadersGetProperty))
    test(Property1UnitTest[Set[String]](_HeadersDeleteProperty))


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


class \nodoc\ iso _HeadersDeleteProperty is Property1[Set[String]]
  fun name(): String => "headers/delete/property"

  fun gen(): Generator[Set[String]] =>
    // we need unique values in our set, lower and upper case letters are
    // considered equal for our Headers impl, so we need to avoid e.g. `a` and
    // `A` as the set thinks they are different, but Headers not.
    Generators.set_of[String](Generators.ascii(where max=10, range=ASCIILettersLower))

  fun property(sample: Set[String], h: PropertyHelper) =>
    let headers = Headers.create()

    let added: Array[String] = Array[String](sample.size())
    let iter = sample.values()
    try
      let first = iter.next()?
      for header in iter do 
          headers.add(header, header)
          added.push(header)
      end

      h.log("Added headers:" where verbose = true)
      for a in added.values() do
        h.log(a where verbose = true)
      end

      // the header we never added is not inside
      h.assert_true(headers.delete(first) is None, "Header: " + first + " got deleted from headers although never added")
      for added_header in added.values() do

        // available before delete
        h.assert_true(headers.get(added_header) isnt None, "Header: " + added_header + " was added to headers, but wasn't retrieved with get")
        h.assert_true(headers.delete(added_header) isnt None, "Header: " + added_header + " was added to headers, but wasn't found during delete")
        // gone after delete
        h.assert_true(headers.get(added_header) is None, "Header: " + added_header + " was deleted but could be retrieved with get")

        // the header we never added is not inside
        h.assert_true(headers.delete(first) is None, "Header: " + first + " got deleted from headers although never added")
      end
    end

