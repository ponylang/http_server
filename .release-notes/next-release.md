## Fix HTTP/1.0 connections not closing without keep-alive

Due to a logic bug this lib was not closing HTTP/1.0 connections when the request wasnt sending a `Connection` header. This caused tools like [ab](https://httpd.apache.org/docs/2.4/programs/ab.html) to hang, as they expect the connection to close to determine when the request is fully done, unless the `-k` flag is provided.

