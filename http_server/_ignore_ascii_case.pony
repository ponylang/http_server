primitive IgnoreAsciiCase
  """
  Compares two strings lexicographically and case-insensitively.
  Only works for ASCII strings.
  """

  fun compare(left: String, right: String): Compare =>
    """

    Less: left sorts lexicographically smaller than right
    Equal: same size, same content
    Greater: left sorts lexicographically higher than right

    _compare("A", "B") ==> Less
    _compare("AA", "A") ==> Greater
    _compare("A", "AA") ==> Less
    _compare("", "") ==> Equal
    """
    let ls = left.size()
    let rs = right.size()
    let min = ls.min(rs)

    var i = USize(0)
    while i < min do
      try
        let lc = _lower(left(i)?)
        let rc = _lower(right(i)?)
        if lc < rc then
          return Less
        elseif rc < lc then
          return Greater
        end
      else
        Less // should not happen, size checked
      end
      i = i + 1
    end
    // all characters equal up to min size
    if ls > min then
      // left side is longer, so considered greater
      Greater
    elseif rs > min then
      // right side is longer, so considered greater
      Less
    else
      // both sides equal size and content
      Equal
    end

  fun eq(left: String, right: String): Bool =>
    """
    Returns true if both strings have the same size
    and compare equal ignoring ASCII casing.
    """
    if left.size() != right.size() then
      false
    else
      var i: USize = 0
      while i < left.size() do
        try
          if _lower(left(i)?) != _lower(right(i)?) then
            return false
          end
        else
          return false
        end
        i = i + 1
      end
      true
    end

  fun _lower(c: U8): U8 =>
    if (c >= 0x41) and (c <= 0x5A) then
      c + 0x20
    else
      c
    end


