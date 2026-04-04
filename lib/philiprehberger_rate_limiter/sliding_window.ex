defmodule Philiprehberger.RateLimiter.SlidingWindow do
  @moduledoc false

  @spec check(:ets.tab(), String.t(), pos_integer(), pos_integer()) ::
          {:ok, map()} | {:error, map()}
  def check(table, key, limit, window_ms) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table, {:sw, key}) do
      [{_key, window_start, count}] ->
        if now - window_start >= window_ms do
          # Window expired, start fresh
          :ets.insert(table, {{:sw, key}, now, 1})
          {:ok, %{remaining: limit - 1, limit: limit, reset_in: window_ms}}
        else
          if count < limit do
            :ets.insert(table, {{:sw, key}, window_start, count + 1})
            elapsed = now - window_start
            reset_in = max(window_ms - elapsed, 0)
            {:ok, %{remaining: limit - count - 1, limit: limit, reset_in: reset_in}}
          else
            elapsed = now - window_start
            retry_after = max(window_ms - elapsed, 1)
            {:error, %{remaining: 0, limit: limit, retry_after: retry_after}}
          end
        end

      [] ->
        :ets.insert(table, {{:sw, key}, now, 1})
        {:ok, %{remaining: limit - 1, limit: limit, reset_in: window_ms}}
    end
  end

  @spec peek(:ets.tab(), String.t(), pos_integer(), pos_integer()) :: {:ok, map()}
  def peek(table, key, limit, window_ms) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table, {:sw, key}) do
      [{_key, window_start, count}] ->
        if now - window_start >= window_ms do
          {:ok, %{remaining: limit, limit: limit, reset_in: 0}}
        else
          elapsed = now - window_start
          reset_in = max(window_ms - elapsed, 0)
          {:ok, %{remaining: max(limit - count, 0), limit: limit, reset_in: reset_in}}
        end

      [] ->
        {:ok, %{remaining: limit, limit: limit, reset_in: 0}}
    end
  end
end
