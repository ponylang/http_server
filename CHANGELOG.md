# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

## [unreleased] - unreleased

### Fixed

- Responses without `Transfer-Encoding: chunked` had no `Content-Length` header set when not done explicitly. This made some clients (e.g. curl) hang.
  Now HTTP Responses either built via `Responses.builder()` or `BuildableResponse` will set a default Content-Length of `0` if none was provided.


### Added

- API additions:
  
  - `ResponseBuilderHeaders.set_content_length(content_length: USize)` has been added to set a content-length from a numeric value.
  - `BuildableResponse.delete_header(header_name: String)` was added to enable deletion of headers that have been set previously.

### Changed

- The API for creating HTTP Responses changed slightly:

  - `ResponseBuilderBody.add_chunk()` now takes a `ByteSeq` instead of `Array[U8] val`. This allows for passing `String val` as well.
  - `BuildableResponse.create()` now only takes a `Status` and a `Version`. Content-Length and Transfer-Encoding can be set later with `set_content_length()` and `set_transfer_encoding()`
  - `BuildableResponse.set_transfer_coding()` changed to `.set_transfer_encoding()`
  - `Response.transfer_coding()` changed to `.transfer_encoding()`.


## [0.4.6] - 2024-01-14

### Changed

- Update to ponylang/net_ssl 1.3.2 ([PR #69](https://github.com/ponylang/http_server/pull/69))

## [0.4.5] - 2023-04-27

### Changed

- Update ponylang/net_ssl dependency ([PR #55](https://github.com/ponylang/http_server/pull/55))

## [0.4.4] - 2023-02-14

### Changed

- Update for json package removal from standard library ([PR #52](https://github.com/ponylang/http_server/pull/52))

## [0.4.3] - 2023-01-03

### Added

- Add OpenSSL 3 support ([PR #51](https://github.com/ponylang/http_server/pull/51))

## [0.4.2] - 2022-08-26

### Fixed

- Update default connection heartbeat length ([PR #47](https://github.com/ponylang/http_server/pull/47))

## [0.4.1] - 2022-02-26

### Fixed

- Update to work with Pony 0.49.0 ([PR #43](https://github.com/ponylang/http_server/pull/43))

## [0.4.0] - 2022-02-02

### Changed

- Update to work with Pony 0.47.0 ([PR #42](https://github.com/ponylang/http_server/pull/42))

## [0.3.3] - 2022-01-16

### Fixed

- Update to work with Pony 0.46.0 ([PR #39](https://github.com/ponylang/http_server/pull/39))

## [0.3.2] - 2021-09-03

### Fixed

- Update to work with ponyc 0.44.0 ([PR #31](https://github.com/ponylang/http_server/pull/31))

## [0.3.1] - 2021-05-07

### Changed

- Update to deal with changes to reference capabilities subtyping rules ([PR #30](https://github.com/ponylang/http_server/pull/30))

## [0.3.0] - 2021-04-10

### Changed

- Don't export test types ([PR #27](https://github.com/ponylang/http_server/pull/27))
- Update net_ssl dependency ([PR #29](https://github.com/ponylang/http_server/pull/29))

## [0.2.4] - 2021-02-20

### Fixed

- BuildableResponse: unify constructor and setter for content length ([PR #23](https://github.com/ponylang/http_server/pull/23))

## [0.2.3] - 2021-02-08

## [0.2.2] - 2020-12-10

### Fixed

- Fix HTTP/1.0 connections not closing without keep-alive ([PR #19](https://github.com/ponylang/http_server/pull/19))

## [0.2.1] - 2020-05-19

### Fixed

- Close Connection when application requested it with Connection: close header ([PR #14](https://github.com/ponylang/http_server/pull/14))

## [0.2.0] - 2020-05-09

### Changed

- Rename package from http/server to http_server. ([PR #6](https://github.com/ponylang/http_server/pull/6))

## [0.1.1] - 2020-05-09

## [0.1.0] - 2020-05-09

