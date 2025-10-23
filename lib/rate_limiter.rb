# frozen_string_literal: true

class RateLimiter
  def initialize(requests_limit = 10, time_period = 60)
    @requests_limit = requests_limit
    @time_period = time_period
    @requests = {} # { user_id => [timestamps] }
    @lock = Mutex.new
  end

  def allow?(user_id)
    @lock.synchronize do
      now = Time.now.to_i
      @requests[user_id] ||= []

      # Remove old timestamps outside the time period
      @requests[user_id].reject! { |timestamp| now - timestamp > @time_period }

      if @requests[user_id].length < @requests_limit
        @requests[user_id] << now
        true
      else
        false
      end
    end
  end

  def reset(user_id = nil)
    @lock.synchronize do
      if user_id.nil?
        @requests.clear
      else
        @requests.delete(user_id)
      end
    end
  end

  def remaining_requests(user_id)
    @lock.synchronize do
      now = Time.now.to_i
      @requests[user_id] ||= []

      # Remove old timestamps outside the time period
      @requests[user_id].reject! { |timestamp| now - timestamp > @time_period }

      [@requests_limit - @requests[user_id].length, 0].max
    end
  end
end
