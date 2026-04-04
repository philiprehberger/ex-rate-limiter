defmodule Philiprehberger.RateLimiter.Server do
  @moduledoc false

  use GenServer

  alias Philiprehberger.RateLimiter.{TokenBucket, SlidingWindow}

  @default_cleanup_interval 60_000

  # Client API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def check(limiter, key, config) do
    table = table_name(limiter)

    case config.algorithm do
      :token_bucket ->
        TokenBucket.check(table, key, config.capacity, config.refill_rate, config.cost)

      :sliding_window ->
        SlidingWindow.check(table, key, config.limit, config.window)
    end
  end

  def peek(limiter, key, config) do
    table = table_name(limiter)

    case config.algorithm do
      :token_bucket ->
        TokenBucket.peek(table, key, config.capacity, config.refill_rate)

      :sliding_window ->
        SlidingWindow.peek(table, key, config.limit, config.window)
    end
  end

  def reset(limiter, key) do
    table = table_name(limiter)
    :ets.match_delete(table, {{:tb, key}, :_, :_})
    :ets.match_delete(table, {{:sw, key}, :_, :_})
    :ok
  end

  def reset_all(limiter) do
    table = table_name(limiter)
    :ets.delete_all_objects(table)
    :ok
  end

  # Server callbacks

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @default_cleanup_interval)
    table = table_name(name)

    :ets.new(table, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])

    schedule_cleanup(cleanup_interval)

    {:ok, %{table: table, cleanup_interval: cleanup_interval}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Clean up expired sliding window entries
    now = System.monotonic_time(:millisecond)

    :ets.foldl(
      fn
        {{:sw, _key} = ets_key, window_start, _count}, acc ->
          # Remove entries older than 5 minutes (conservative cleanup)
          if now - window_start > 300_000 do
            :ets.delete(state.table, ets_key)
          end

          acc

        {{:tb, _key} = ets_key, _tokens, last_time}, acc ->
          # Remove token bucket entries not accessed in 5 minutes
          if now - last_time > 300_000 do
            :ets.delete(state.table, ets_key)
          end

          acc
      end,
      nil,
      state.table
    )

    schedule_cleanup(state.cleanup_interval)
    {:noreply, state}
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp table_name(limiter) when is_atom(limiter) do
    :"#{limiter}_rate_limiter_table"
  end
end
