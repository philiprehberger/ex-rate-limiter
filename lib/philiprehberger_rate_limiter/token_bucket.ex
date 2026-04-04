defmodule Philiprehberger.RateLimiter.TokenBucket do
  @moduledoc false

  @spec check(:ets.tab(), String.t(), pos_integer(), number(), pos_integer()) ::
          {:ok, map()} | {:error, map()}
  def check(table, key, capacity, refill_rate, cost) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table, {:tb, key}) do
      [{_key, tokens, last_time}] ->
        elapsed_ms = max(now - last_time, 0)
        refilled = tokens + elapsed_ms * refill_rate / 1000.0
        current = min(refilled, capacity * 1.0)
        consume(table, key, current, capacity, refill_rate, cost, now)

      [] ->
        consume(table, key, capacity * 1.0, capacity, refill_rate, cost, now)
    end
  end

  @spec peek(:ets.tab(), String.t(), pos_integer(), number()) :: {:ok, map()}
  def peek(table, key, capacity, refill_rate) do
    now = System.monotonic_time(:millisecond)

    current =
      case :ets.lookup(table, {:tb, key}) do
        [{_key, tokens, last_time}] ->
          elapsed_ms = max(now - last_time, 0)
          refilled = tokens + elapsed_ms * refill_rate / 1000.0
          min(refilled, capacity * 1.0)

        [] ->
          capacity * 1.0
      end

    remaining = trunc(current)

    reset_in =
      if remaining < capacity, do: trunc((capacity - current) / refill_rate * 1000), else: 0

    {:ok, %{remaining: remaining, limit: capacity, reset_in: reset_in}}
  end

  defp consume(table, key, current, capacity, refill_rate, cost, now) do
    if current >= cost do
      new_tokens = current - cost
      :ets.insert(table, {{:tb, key}, new_tokens, now})
      remaining = trunc(new_tokens)

      reset_in =
        if remaining < capacity, do: trunc((capacity - new_tokens) / refill_rate * 1000), else: 0

      {:ok, %{remaining: remaining, limit: capacity, reset_in: reset_in}}
    else
      :ets.insert(table, {{:tb, key}, current, now})
      deficit = cost - current
      retry_after = trunc(deficit / refill_rate * 1000)
      {:error, %{remaining: 0, limit: capacity, retry_after: max(retry_after, 1)}}
    end
  end
end
