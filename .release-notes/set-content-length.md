## Always set Content-Length

There was a bug where the Content-Length header could end up not being sent. This would cause many clients (such as curl) to hang.
