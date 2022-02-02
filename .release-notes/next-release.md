## Update to work with Pony 0.47.0

Pony 0.47.0 disallows interfaces having private methods. We've updated accordingly. `HTTP11RequestHandler` and `Session` are now traits instead of interfaces. If you are subtyping them by structural typing, you'll now need to use nominal typing.

Previously:

```pony
class MyRequestHandler
```

would become:

```pony
class MyRequestHandler is Session
```

