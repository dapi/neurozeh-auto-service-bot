require_relative 'test_helper'

class TestRateLimiter < Minitest::Test
  def setup
    @limiter = RateLimiter.new(3, 10) # 3 requests per 10 seconds
  end

  def test_allow_within_limit
    assert @limiter.allow?(1), "Should allow first request"
    assert @limiter.allow?(1), "Should allow second request"
    assert @limiter.allow?(1), "Should allow third request"
  end

  def test_deny_over_limit
    3.times { @limiter.allow?(1) }
    assert !@limiter.allow?(1), "Should deny fourth request"
  end

  def test_different_users_independent
    assert @limiter.allow?(1), "User 1 should be allowed"
    assert @limiter.allow?(2), "User 2 should be allowed"
    3.times { @limiter.allow?(1) }
    assert !@limiter.allow?(1), "User 1 should be blocked"
    assert @limiter.allow?(2), "User 2 should still be allowed"
  end

  def test_reset_single_user
    3.times { @limiter.allow?(1) }
    assert !@limiter.allow?(1), "User 1 should be blocked"
    @limiter.reset(1)
    assert @limiter.allow?(1), "User 1 should be allowed after reset"
  end

  def test_reset_all_users
    3.times { @limiter.allow?(1) }
    3.times { @limiter.allow?(2) }
    @limiter.reset
    assert @limiter.allow?(1), "User 1 should be allowed after reset all"
    assert @limiter.allow?(2), "User 2 should be allowed after reset all"
  end

  def test_remaining_requests
    assert_equal 3, @limiter.remaining_requests(1)
    @limiter.allow?(1)
    assert_equal 2, @limiter.remaining_requests(1)
    @limiter.allow?(1)
    @limiter.allow?(1)
    assert_equal 0, @limiter.remaining_requests(1)
  end
end
