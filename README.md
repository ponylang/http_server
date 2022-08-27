# http_server

Pony package to build server applications for the HTTP protocol.

## Status

`http_server` is beta quality software that will change frequently. Expect breaking changes. That said, you should feel comfortable using it in your projects.

## Installation

* Install [corral](https://github.com/ponylang/corral):
* `corral add github.com/ponylang/http_server.git --version 0.4.2`
* Execute `corral fetch` to fetch your dependencies.
* Include this package by adding `use "http_server"` to your Pony sources.
* Execute `corral run -- ponyc` to compile your application

Note: The `net_ssl` transitive dependency requires a C SSL library to be installed. Please see the [net_ssl installation instructions](https://github.com/ponylang/net_ssl#installation) for more information.

## API Documentation

[https://ponylang.github.io/http_server](https://ponylang.github.io/http_server)
