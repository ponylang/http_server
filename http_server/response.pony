use "valbytes"
use "format"

interface val Response is ByteSeqIter
  """
  Representing a HTTP response minus the body.
  """
  fun version(): Version
  fun status(): Status
  fun header(name: String): (String | None)
  fun headers(): Iterator[Header]
  fun transfer_encoding(): (Chunked | None)
  fun content_length(): (USize | None)
  fun to_bytes(): ByteArrays
  fun array(): Array[U8] iso^

primitive Responses // TODO: better naming
  """
  The entry-point into building Responses.
  """
  fun builder(version: Version = HTTP11): ResponseBuilder =>
    """
    Official way to get a reusable [ResponseBuilder](http_server-ResponseBuilder.md)
    to build your responses efficiently.
    """
    _FullResponseBuilder._create(version)

interface ResponseBuilder
  """
  Basic interface for a ResponseBuilder that can be used with chaining method calls.
  It enforces a strict order of build steps by only making the next step available
  as a return to a function required to transition. E.g. You must call `set_status(...)`
  in order to get back a [ResponseBuilderHeaders](http_server-ResponseBuilderHeaders.md) to add
  headers to the response. You need to call `finish_headers()` in order to
  be able to add body data with [ResponseBuilderBody](http_server-ResponseBuilderBody.md).

  You can always reset the builder to start out fresh from the beginning.
  Implementations may take advantage of `reset()` by returning itself here,
  allowing for object reuse.

  Use [ResponseBuilderBody.build()](http_server-ResponseBuilderBody.md#build) to finally build the
  response into a [ByteSeqIter](builtin-ByteSeqIter.md),
  taylored for use with [Session.send_raw()](http_server-Session.md#send_raw).

  Example usage:

  ```pony
  let builder: ResponseBuilder = Responses.builder()
  builder.set_status(StatusOK)
         .add_header("Content-Length", "4")
         .add_header("Content-Type", "text/plain; charset=UTF-8")
         .add_header("Server", "pony-http")
         .finish_headers()
         .add_chunk("COOL")
         .build()
  ```
  """
  fun ref set_status(status: Status): ResponseBuilderHeaders
  fun ref reset(): ResponseBuilder

interface ResponseBuilderHeaders
  fun ref add_header(name: String, value: String): ResponseBuilderHeaders
  fun ref set_content_length(content_length: USize): ResponseBuilderHeaders
  fun ref set_transfer_encoding(chunked: (Chunked | None)): ResponseBuilderHeaders
  fun ref finish_headers(): ResponseBuilderBody
  fun ref reset(): ResponseBuilder

interface ResponseBuilderBody
  fun ref add_chunk(data: ByteSeq): ResponseBuilderBody
    """
    Add some body data.

    If Transfer-Encoding is set to [Chunked](http_server-Chunked.md) in [ResponseBuilderHeaders](http_server-ResponseBuilderHeaders.md)
    each call to this function will take care of encoding every added array here in Chunked encoding.
    Add an empty array to add the finishing chunk..
    """
  fun ref build(): ByteSeqIter
    """
    Serialize the accumulated response data into a [ByteSeqIter](builtin-ByteSeqIter.md).
    """
  fun ref reset(): ResponseBuilder
    """
    Reset the builder to a fresh state, only use the returned builder for further actions.
    """

class iso _FullResponseBuilder
  """
  Efficient HTTP response builder
  backed by a byte array to which we only append.

  Will write multiple chunks into separate arrays only if
  they exceed 65535 bytes (arbitrary choice).
  Otherwise appends to the same array, in order to not bog up
  writev calls with tiny arrays, which makes it very much inefficient.

  Keep your arrays decently sized at all times!

  This instance is `iso`, so you can safely send it around amongst your actors.
  """
  let _version: Version
  let _empty_placeholder: Array[U8] val = recover val _empty_placeholder.create(0) end
  let _crlf: Array[U8] val = [as U8: '\r'; '\n']
  let _header_sep: Array[U8] val = [as U8: ':'; ' ']

  var _array: Array[U8] iso
  var _chunks: Array[Array[U8] val] iso
  var _transfer_encoding: (Chunked | None)
  var _content_length_set: Bool
  var _needs_reset: Bool = false

  new iso _create(version: Version = HTTP11) =>
    _version = version
    _array = (recover iso Array[U8].create(128) end)
      .>append(_version.to_bytes())
      .>append(" ")
    _chunks = (recover iso Array[Array[U8] val](1) end)
      .>push(_empty_placeholder)
    _transfer_encoding = None
    _content_length_set = false

  fun ref reset(): ResponseBuilder =>
    if _needs_reset then
      _array = (recover iso Array[U8].create(128) end)
        .>append(_version.to_bytes())
        .>append(" ")
      _chunks = (recover iso Array[Array[U8] val](1) end)
        .>push(_empty_placeholder)
      _transfer_encoding = None
      _content_length_set = false
    end
    _needs_reset = false
    this

  fun ref set_status(status: Status): ResponseBuilderHeaders =>
    _array.>append(status.string())
         .>append(_crlf)
    _needs_reset = true
    this

  fun ref finish_headers(): ResponseBuilderBody =>
    if (not _content_length_set) and (_transfer_encoding is None) then
      add_header("Content-Length", "0")
    end
    _array.append(_crlf)
    _needs_reset = true
    this

  fun ref add_header(name: String, value: String): ResponseBuilderHeaders =>
    // this is quite costly, but the only reliable way to ensure
    // we always set a content-length when needed
    if IgnoreAsciiCase.eq(name, "content-length") then
      this._content_length_set = true
    end
    _array
        .>append(name)
        .>append(_header_sep)
        .>append(value)
        .>append(_crlf)
    _needs_reset = true
    this

  fun ref set_transfer_encoding(chunked: (Chunked | None)): ResponseBuilderHeaders =>
    """
    This will also add the Transfer-Encoding header if set to `Chunked`.
    """
    match chunked
    | Chunked =>
      add_header("Transfer-Encoding", "chunked")
    end
    _transfer_encoding = chunked
    _needs_reset = true
    this

  fun ref set_content_length(content_length: USize): ResponseBuilderHeaders =>
    """
    Set the Content-Length header.
    """
    add_header("Content-Length", content_length.string())

  fun ref add_chunk(data: ByteSeq): ResponseBuilderBody =>
    """
    content-length needs to be set before this happens.
    In case of chunked transfer-encoding this will be encoded into proper chunks.
    """
    let d = match data
    | let array: Array[U8] val => array
    | let string: String val => string.array()
    end
    if (d.size() < 65535) and (_chunks.size() == 1) then
      // we can only append to the response array if we have no chunk yet added
      // to chunks (1 means 0 as we always put a placeholder)
      if _transfer_encoding is Chunked then
        _array
          .>append(
            (recover val Format.int[USize](d.size() where fmt = FormatHexBare).>append(_crlf) end).array())
          .>append(d)
          .append(_crlf)
      else
        _array.append(d)
      end
    else
      if _transfer_encoding is Chunked then
        _chunks
          .>push(
            (recover val Format.int[USize](d.size() where fmt = FormatHexBare).>append(_crlf) end).array())
          .>push(d)
          .push(_crlf)
      else
        _chunks.push(d)
      end
    end
    _needs_reset = true
    this

  fun ref build(): ByteSeqIter =>
    """
    Build 
    In the case of chunked Transfer Encoding this will not add the final chunk
    Do this manually by doing the following before actually calling `build()`:

    ```pony
    builder.add_chunk("")
    ```
    """
    let response =
      (_array = (recover iso Array[U8].create(128) end)
                 .>append(_version.to_bytes())
                 .>append(" "))
    try
      // should never fail. is always initialized with empty_placeholder at
      // index 0
      _chunks(0)? = consume response
    end
    let byteseqs = (_chunks = (recover iso Array[Array[U8] val](1) end)
      .>push(_empty_placeholder))
    _transfer_encoding = None
    _content_length_set = false
    _needs_reset = false
    consume byteseqs


// TODO: make internal state a ByteArrays instance and only keep track of
// indices pointing to values
class val BuildableResponse is (Response & ByteSeqIter)
  """
  Build your own HTTP Responses (minus the body) and turn them into immutable
  things to send around.

  This class can be serialized in the following ways:

  * to Array[U8]: BuildableResponse.array()
  * to ByteArrays: BuildableResponse.to_bytes()

  or by using it as a ByteSeqIter.

  This class exists if you want to use the verbose API of [Session](http_server-Session.md)
  and brings lots of convenience, like getters and setters for all common properties.

  If you are looking for a more efficient way to build responses, use a [ResponseBuilder](http_server-ResponseBuilder.md)
  as it is returned from [Responses.builder()](http_server-Responses.md#builder), this class is not introspectable
  and only allows adding properties the way they are put on the serialized form in the request. E.g. you must first
  set the status and then the headers, not the other way around. But it makes for a more efficient API.
  """
  var _version: Version
  var _status: Status
  embed _headers: Headers = _headers.create()

  new trn create(
    status': Status = StatusOK,
    version': Version = HTTP11)
  =>
    _status = status'
    _version = version'

  fun version(): Version => _version

  fun ref set_version(v: Version): BuildableResponse ref =>
    _version = v
    this

  fun status(): Status => _status

  fun ref set_status(s: Status): BuildableResponse ref =>
    _status = s
    this

  fun header(name: String): (String | None) => _headers.get(name)

  fun headers(): Iterator[Header] => _headers.values()

  fun ref add_header(name: String, value: String): BuildableResponse ref =>
    _headers.add(name, value)
    this

  fun ref set_header(name: String, value: String): BuildableResponse ref =>
    _headers.set(name, value)
    this

  fun ref delete_header(name: String): BuildableResponse ref =>
    _headers.delete(name)
    this

  fun ref clear_headers(): BuildableResponse ref =>
    _headers.clear()
    this

  fun transfer_encoding(): (Chunked | None) =>
    match _headers.get("transfer-encoding")
    | let te: String if te.contains("chunked") => Chunked
    end

  fun ref set_transfer_encoding(c: (Chunked | None)): BuildableResponse ref =>
    match c
    | Chunked =>
      set_header("Transfer-Encoding", "chunked")
      set_content_length(None) // no content-length allowed for chunked encoding
    | None =>
      delete_header("Transfer-Encoding")
    end
    this

  fun content_length(): (USize | None) =>
    match _headers.get("content-length")
    | let cl: String => try cl.usize()? end
    end

  fun ref set_content_length(cl: (USize | None)): BuildableResponse ref =>
    """
    Set or un-set the `Content-Length` header.
    """
    match cl
    | let clu: USize =>
      set_header("Content-Length", clu.string())
    | None =>
      delete_header("Content-Length")
    end
    this

  fun box array(): Array[U8] iso^ =>
    let sp: Array[U8] val =   [as U8: ' ']
    let crlf: Array[U8] val = [as U8: '\r'; '\n']
    let header_sep: Array[U8] val = [as U8: ':'; ' ']
    let version_bytes = _version.to_bytes()
    let status_bytes = _status.string()
    let header_size = _headers.byte_size()
    let arr =
      recover iso
        Array[U8](
          version_bytes.size() + 1 + status_bytes.size() + 2 + header_size + 2)
      end
    arr.>append(version_bytes)
       .>append(sp)
       .>append(status_bytes)
       .append(crlf)

    for (hname, hvalue) in headers() do
      arr.>append(hname)
         .>append(header_sep)
         .>append(_format_multiline(hvalue))
         .>append(crlf)
    end

    // inject content-length if needed
    let needs_content_length = transfer_encoding() is None
    let no_content_length_provided = _headers.get("content-length") is None
    if needs_content_length and no_content_length_provided then
      arr.>append("Content-Length: 0\r\n")
    end

    arr.append(crlf)
    consume arr

  fun box to_bytes(): ByteArrays =>
    let sp: Array[U8] val =   [as U8: ' ']
    let crlf: Array[U8] val = [as U8: '\r'; '\n']
    let header_sep: Array[U8] val = [as U8: ':'; ' ']
    var acc = ByteArrays(version().to_bytes(), sp) + status().string() + crlf

    for (hname, hvalue) in headers() do
      acc = acc + hname + header_sep + _format_multiline(hvalue) + crlf
    end

    // inject content-length if needed
    let needs_content_length = transfer_encoding() is None
    let no_content_length_provided = _headers.get("content-length") is None
    if needs_content_length and no_content_length_provided then
      acc = acc + "Content-Length: 0\r\n"
    end
    (acc + crlf)

  fun values(): Iterator[this->ByteSeq box] =>
    """
    Make this a very inefficient ByteSeqIter.
    Rather use `array()` if you care about performance.
    """
    to_bytes().arrays().values()

  fun tag _format_multiline(header_value: String): String =>
    // TODO
    header_value
