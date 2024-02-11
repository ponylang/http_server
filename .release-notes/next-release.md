## Ensure Content-Length is set for all Responses that need it

Previously responses without explicitly added Content-Length didn't add that header with a `0` value. This made some HTTP clients hang.
Now all responses built with this library will have a default `Content-Length` header set, unless marked with `Transfer-Encoding: chunked`

## Response Creation API changes and Additions

  - `Response.transfer_coding()` changed to `Response.transfer_encoding()`.

  - `ResponseBuilderHeaders.set_content_length(content_length: USize)` has been added to set a content-length from a numeric value.
  - `ResponseBuilderBody.add_chunk()` now takes a `ByteSeq` instead of `Array[U8] val`. This allows for passing `String val` as well.

  - `BuildableResponse.create()` now only takes a `Status` and a `Version`. Content-Length and Transfer-Encoding can be set later with `set_content_length()` and `set_transfer_encoding()`
  - `BuildableResponse.delete_header(header_name: String)` was added to enable deletion of headers that have been set previously.
  - `BuildableResponse.set_transfer_coding()` changed to `BuildableResponse.set_transfer_encoding()`
