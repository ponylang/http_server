// TODO rename to just _ProtocolHandler?
interface _ServerConnectionProtocol
  """
  Responsible for parsing incoming requests per applicaton protocol and
  handing them off to the user provided handler.

  Executes within the context of the `_ServerConnection` actor.
  """
  fun ref received(data: Array[U8] iso)
    """
    """

  fun ref closed() =>
    """
    Notification that the underlying connection has been closed.
    """

  fun ref throttled() =>
    """
    Notification that the session temporarily can not accept more data.
    """

  fun ref unthrottled() =>
    """
    Notification that the session can resume accepting data.
    """
