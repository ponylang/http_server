## Fix missing Content-Length header

Setting a content length via the `BuildableResponse` constructor didn't set the corresponding header
