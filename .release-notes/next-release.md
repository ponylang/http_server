## Ensure Content-Length is set for all Responses that need it

Previously responses without explicitly added Content-Length didn't add that header with a `0` value. This made some HTTP clients hang.
Now all responses built with this library will have a default `Content-Length` header set, unless marked with `Transfer-Encoding: chunked`

## Added `ResponseBuilderHeaders.set_content_length(content_length: USize)`

This way it is more convenient to set a content-length from a numeric value. E.g. from the size of a prepared array to be passed as HTTP body:

```pony
let body = "I am a teapot"
let response = 
  Responses.builder()
    .set_status(StatusOK)
    .set_content_length(body.size())
    .add_header("Content-Type", "text/plain")
    .finish_headers()
    .add_chunk(body)
    .build()
```

## Added `BuildableResponse.delete_header(header_name: String)`

Previously it was not possible to delete a header, once set it was permanent. No it is possible to delete a header e.g. in multi-stage processing of a HTTP response.

## `ResponseBuilderBody.add_chunk()` now takes a `ByteSeq` instead of `Array[U8] val`

This allows to pass `String val` as well as `Array[U8] val` to `add_chunk`.

```pony
let response = Responses.builder()
  .set_content_length(7)
  .finish_headers()
  .add_chunk("AWESOME")
  .build()
```

## `BuildableResponse.create()` now only takes a `Status` and optionally a `Version`

The logic applied to set `content_length` and `transfer_encoding` from the constructor parameters was a bit brittle, so it got removed. Use both `set_content_length(content_length: USize)` and `set_transfer_encoding(chunked: (Chunked | None))` to set them:

```pony
let body = "AWESOME"
let response = BuildableResponse
  .create(StatusOK)
  .set_content_length(body.size())
  .set_header("Content-Type", "text/plain")
```

## `Response.transfer_coding()` changed to `.transfer_encoding()`

The wording now is now equal to the actual header name set with this method.

## `BuildableResponse.set_transfer_coding()` changed to `.set_transfer_encoding()`

Following the `Response` trait.
