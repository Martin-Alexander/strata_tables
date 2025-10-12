module TimestampingHelper
  def t(n)
    @timestamps ||= []
    @timestamps[n] ||= Time.current
  end

  def now
    Time.current
  end

  def respond_to_missing?(m, include_private = false)
    m.match?(/t_(\d+)/) || super
  end

  def method_missing(m, *args, &block)
    if (match = m.match(/t_(\d+)/))
      send(:t, match[1].to_i)
    else
      super
    end
  end
end
