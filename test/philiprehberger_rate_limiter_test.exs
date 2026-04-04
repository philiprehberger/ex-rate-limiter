defmodule Philiprehberger.RateLimiterTest do
  use ExUnit.Case, async: false

  alias Philiprehberger.RateLimiter

  setup do
    name = :"limiter_#{:erlang.unique_integer([:positive])}"
    {:ok, _pid} = RateLimiter.start_link(name: name, cleanup_interval: 600_000)
    {:ok, limiter: name}
  end

  describe "start_link/1" do
    test "starts with a name" do
      name = :"start_test_#{:erlang.unique_integer([:positive])}"
      assert {:ok, pid} = RateLimiter.start_link(name: name)
      assert Process.alive?(pid)
    end

    test "raises without name" do
      assert_raise KeyError, fn ->
        RateLimiter.start_link([])
      end
    end
  end

  describe "check/3 with token bucket" do
    test "allows requests within capacity", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 5, refill_rate: 1]
      assert {:ok, %{remaining: 4, limit: 5}} = RateLimiter.check(limiter, "user:1", opts)
      assert {:ok, %{remaining: 3, limit: 5}} = RateLimiter.check(limiter, "user:1", opts)
    end

    test "denies requests when exhausted", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 2, refill_rate: 1]
      assert {:ok, _} = RateLimiter.check(limiter, "user:2", opts)
      assert {:ok, _} = RateLimiter.check(limiter, "user:2", opts)

      assert {:error, %{remaining: 0, retry_after: retry}} =
               RateLimiter.check(limiter, "user:2", opts)

      assert retry > 0
    end

    test "respects cost parameter", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 10, refill_rate: 1, cost: 5]
      assert {:ok, %{remaining: 5}} = RateLimiter.check(limiter, "user:3", opts)
      assert {:ok, %{remaining: 0}} = RateLimiter.check(limiter, "user:3", opts)
      assert {:error, _} = RateLimiter.check(limiter, "user:3", opts)
    end

    test "different keys are independent", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 1, refill_rate: 1]
      assert {:ok, _} = RateLimiter.check(limiter, "user:a", opts)
      assert {:ok, _} = RateLimiter.check(limiter, "user:b", opts)
      assert {:error, _} = RateLimiter.check(limiter, "user:a", opts)
      assert {:error, _} = RateLimiter.check(limiter, "user:b", opts)
    end

    test "tokens refill over time", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 1, refill_rate: 1000]
      assert {:ok, _} = RateLimiter.check(limiter, "user:refill", opts)
      assert {:error, _} = RateLimiter.check(limiter, "user:refill", opts)
      Process.sleep(10)
      assert {:ok, _} = RateLimiter.check(limiter, "user:refill", opts)
    end

    test "returns reset_in", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 10, refill_rate: 1]
      assert {:ok, %{reset_in: reset_in}} = RateLimiter.check(limiter, "user:reset", opts)
      assert is_integer(reset_in)
      assert reset_in >= 0
    end
  end

  describe "check/3 with sliding window" do
    test "allows requests within limit", %{limiter: limiter} do
      opts = [algorithm: :sliding_window, limit: 5, window: 60_000]
      assert {:ok, %{remaining: 4, limit: 5}} = RateLimiter.check(limiter, "sw:1", opts)
      assert {:ok, %{remaining: 3, limit: 5}} = RateLimiter.check(limiter, "sw:1", opts)
    end

    test "denies requests over limit", %{limiter: limiter} do
      opts = [algorithm: :sliding_window, limit: 2, window: 60_000]
      assert {:ok, _} = RateLimiter.check(limiter, "sw:2", opts)
      assert {:ok, _} = RateLimiter.check(limiter, "sw:2", opts)

      assert {:error, %{remaining: 0, retry_after: retry}} =
               RateLimiter.check(limiter, "sw:2", opts)

      assert retry > 0
    end

    test "window resets after expiry", %{limiter: limiter} do
      opts = [algorithm: :sliding_window, limit: 1, window: 10]
      assert {:ok, _} = RateLimiter.check(limiter, "sw:expire", opts)
      assert {:error, _} = RateLimiter.check(limiter, "sw:expire", opts)
      Process.sleep(15)
      assert {:ok, _} = RateLimiter.check(limiter, "sw:expire", opts)
    end

    test "different keys are independent", %{limiter: limiter} do
      opts = [algorithm: :sliding_window, limit: 1, window: 60_000]
      assert {:ok, _} = RateLimiter.check(limiter, "sw:a", opts)
      assert {:ok, _} = RateLimiter.check(limiter, "sw:b", opts)
      assert {:error, _} = RateLimiter.check(limiter, "sw:a", opts)
    end

    test "returns reset_in", %{limiter: limiter} do
      opts = [algorithm: :sliding_window, limit: 10, window: 60_000]
      assert {:ok, %{reset_in: reset_in}} = RateLimiter.check(limiter, "sw:reset", opts)
      assert is_integer(reset_in)
      assert reset_in > 0
    end
  end

  describe "peek/3" do
    test "does not consume tokens", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 5, refill_rate: 1]
      assert {:ok, %{remaining: 5}} = RateLimiter.peek(limiter, "peek:1", opts)
      assert {:ok, %{remaining: 5}} = RateLimiter.peek(limiter, "peek:1", opts)
    end

    test "reflects consumed tokens", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 5, refill_rate: 1]
      RateLimiter.check(limiter, "peek:2", opts)
      assert {:ok, %{remaining: 4}} = RateLimiter.peek(limiter, "peek:2", opts)
    end

    test "works with sliding window", %{limiter: limiter} do
      opts = [algorithm: :sliding_window, limit: 10, window: 60_000]
      assert {:ok, %{remaining: 10}} = RateLimiter.peek(limiter, "peek:sw", opts)
      RateLimiter.check(limiter, "peek:sw", opts)
      assert {:ok, %{remaining: 9}} = RateLimiter.peek(limiter, "peek:sw", opts)
    end
  end

  describe "status/3" do
    test "returns info map directly", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 10, refill_rate: 1]
      info = RateLimiter.status(limiter, "status:1", opts)
      assert %{remaining: 10, limit: 10, reset_in: _} = info
    end
  end

  describe "reset/2" do
    test "resets a specific key", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 2, refill_rate: 1]
      RateLimiter.check(limiter, "reset:1", opts)
      RateLimiter.check(limiter, "reset:1", opts)
      assert {:error, _} = RateLimiter.check(limiter, "reset:1", opts)

      :ok = RateLimiter.reset(limiter, "reset:1")
      assert {:ok, %{remaining: 1}} = RateLimiter.check(limiter, "reset:1", opts)
    end

    test "does not affect other keys", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 5, refill_rate: 1]
      RateLimiter.check(limiter, "reset:a", opts)
      RateLimiter.check(limiter, "reset:b", opts)

      RateLimiter.reset(limiter, "reset:a")

      assert {:ok, %{remaining: 4}} = RateLimiter.peek(limiter, "reset:b", opts)
      assert {:ok, %{remaining: 5}} = RateLimiter.peek(limiter, "reset:a", opts)
    end
  end

  describe "reset_all/1" do
    test "resets all keys", %{limiter: limiter} do
      opts = [algorithm: :token_bucket, capacity: 5, refill_rate: 1]
      RateLimiter.check(limiter, "all:a", opts)
      RateLimiter.check(limiter, "all:b", opts)

      :ok = RateLimiter.reset_all(limiter)

      assert {:ok, %{remaining: 5}} = RateLimiter.peek(limiter, "all:a", opts)
      assert {:ok, %{remaining: 5}} = RateLimiter.peek(limiter, "all:b", opts)
    end
  end

  describe "config validation" do
    test "raises on invalid algorithm", %{limiter: limiter} do
      assert_raise ArgumentError, ~r/algorithm must be/, fn ->
        RateLimiter.check(limiter, "x", algorithm: :invalid, capacity: 1, refill_rate: 1)
      end
    end

    test "raises on missing capacity for token bucket", %{limiter: limiter} do
      assert_raise KeyError, fn ->
        RateLimiter.check(limiter, "x", algorithm: :token_bucket, refill_rate: 1)
      end
    end

    test "raises on missing limit for sliding window", %{limiter: limiter} do
      assert_raise KeyError, fn ->
        RateLimiter.check(limiter, "x", algorithm: :sliding_window, window: 1000)
      end
    end

    test "raises on non-positive capacity", %{limiter: limiter} do
      assert_raise ArgumentError, ~r/capacity must be/, fn ->
        RateLimiter.check(limiter, "x", algorithm: :token_bucket, capacity: 0, refill_rate: 1)
      end
    end

    test "raises on non-positive refill_rate", %{limiter: limiter} do
      assert_raise ArgumentError, ~r/refill_rate must be/, fn ->
        RateLimiter.check(limiter, "x", algorithm: :token_bucket, capacity: 1, refill_rate: -1)
      end
    end
  end
end
