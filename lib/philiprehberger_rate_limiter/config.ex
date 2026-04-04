defmodule Philiprehberger.RateLimiter.Config do
  @moduledoc false

  @type t :: %{
          algorithm: :token_bucket | :sliding_window,
          capacity: pos_integer() | nil,
          refill_rate: number() | nil,
          cost: pos_integer(),
          limit: pos_integer() | nil,
          window: pos_integer() | nil
        }

  @spec validate!(keyword()) :: t()
  def validate!(opts) do
    algorithm = Keyword.fetch!(opts, :algorithm)

    unless algorithm in [:token_bucket, :sliding_window] do
      raise ArgumentError,
            "algorithm must be :token_bucket or :sliding_window, got: #{inspect(algorithm)}"
    end

    config = %{algorithm: algorithm, cost: Keyword.get(opts, :cost, 1)}

    case algorithm do
      :token_bucket -> validate_token_bucket!(opts, config)
      :sliding_window -> validate_sliding_window!(opts, config)
    end
  end

  defp validate_token_bucket!(opts, config) do
    capacity = Keyword.fetch!(opts, :capacity)
    refill_rate = Keyword.fetch!(opts, :refill_rate)

    unless is_integer(capacity) and capacity > 0 do
      raise ArgumentError, "capacity must be a positive integer, got: #{inspect(capacity)}"
    end

    unless is_number(refill_rate) and refill_rate > 0 do
      raise ArgumentError, "refill_rate must be a positive number, got: #{inspect(refill_rate)}"
    end

    unless is_integer(config.cost) and config.cost > 0 do
      raise ArgumentError, "cost must be a positive integer, got: #{inspect(config.cost)}"
    end

    Map.merge(config, %{capacity: capacity, refill_rate: refill_rate, limit: nil, window: nil})
  end

  defp validate_sliding_window!(opts, config) do
    limit = Keyword.fetch!(opts, :limit)
    window = Keyword.fetch!(opts, :window)

    unless is_integer(limit) and limit > 0 do
      raise ArgumentError, "limit must be a positive integer, got: #{inspect(limit)}"
    end

    unless is_integer(window) and window > 0 do
      raise ArgumentError,
            "window must be a positive integer (milliseconds), got: #{inspect(window)}"
    end

    Map.merge(config, %{limit: limit, window: window, capacity: nil, refill_rate: nil})
  end
end
