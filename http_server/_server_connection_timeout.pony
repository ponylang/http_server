use "time"

class _ServerConnectionTimeout
  var _last_activity_ts: I64 = Time.seconds()

  fun box last_activity_ts(): I64 => _last_activity_ts

  fun ref reset() =>
    _last_activity_ts = Time.seconds()
