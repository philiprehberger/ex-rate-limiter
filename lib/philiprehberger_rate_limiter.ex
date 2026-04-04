defmodule Philiprehberger.RateLimiter do
  @moduledoc """
  In-process rate limiter with token bucket and sliding window algorithms.

  ## Quick Start

      # Add to your supervision tree
      children = [
        {Philiprehberger.RateLimiter, name: :my_limiter}
      ]

      # Check a rate limit
      case Philiprehberger.RateLimiter.check(:my_limiter, "user:123",
             algorithm: :token_bucket,
             capacity: 100,
             refill_rate: 10
           ) do
        {:ok, info} -> # allowed, info.remaining tokens left
        {:error, info} -> # denied, retry in info.retry_after ms
      end
  """

  alias Philiprehberger.RateLimiter.{Config, Server}

  @type info :: %{
          remaining: non_neg_integer(),
          limit: pos_integer(),
          reset_in: non_neg_integer()
        }

  @type error_info :: %{
          remaining: 0,
          limit: pos_integer(),
          retry_after: non_neg_integer()
        }

  @doc """
  Starts the rate limiter process.

  ## Options

    * `:name` - Required. The name to register the limiter under.
    * `:cleanup_interval` - Optional. Milliseconds between cleanup sweeps. Default: 60_000.

  ## Examples

      # In a supervision tree
      children = [
        {Philiprehberger.RateLimiter, name: :api_limiter}
      ]

      # Standalone
      {:ok, _pid} = Philiprehberger.RateLimiter.start_link(name: :api_limiter)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    Server.start_link(opts)
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc """
  Checks the rate limit for the given key and consumes one unit.

  Returns `{:ok, info}` if allowed or `{:error, info}` if rate limited.

  ## Options

    * `:algorithm` - `:token_bucket` or `:sliding_window`. Required.
    * `:capacity` - Maximum tokens (token bucket). Required for token bucket.
    * `:refill_rate` - Tokens per second (token bucket). Required for token bucket.
    * `:cost` - Tokens to consume per check. Default: 1.
    * `:limit` - Maximum requests per window (sliding window). Required for sliding window.
    * `:window` - Window size in milliseconds (sliding window). Required for sliding window.

  ## Examples

      # Token bucket
      {:ok, %{remaining: 99}} =
        Philiprehberger.RateLimiter.check(:limiter, "user:1",
          algorithm: :token_bucket,
          capacity: 100,
          refill_rate: 10
        )

      # Sliding window
      {:ok, %{remaining: 59}} =
        Philiprehberger.RateLimiter.check(:limiter, "ip:1.2.3.4",
          algorithm: :sliding_window,
          limit: 60,
          window: 60_000
        )
  """
  @spec check(GenServer.name(), String.t(), keyword()) :: {:ok, info()} | {:error, error_info()}
  def check(limiter, key, opts) do
    config = Config.validate!(opts)
    Server.check(limiter, key, config)
  end

  @doc """
  Peeks at the current rate limit status without consuming a unit.

  ## Examples

      {:ok, %{remaining: 45, limit: 100, reset_in: 8000}} =
        Philiprehberger.RateLimiter.peek(:limiter, "user:1",
          algorithm: :token_bucket,
          capacity: 100,
          refill_rate: 10
        )
  """
  @spec peek(GenServer.name(), String.t(), keyword()) :: {:ok, info()}
  def peek(limiter, key, opts) do
    config = Config.validate!(opts)
    Server.peek(limiter, key, config)
  end

  @doc """
  Returns the current status for a key.

  ## Examples

      %{remaining: 45, limit: 100, reset_in: 8000} =
        Philiprehberger.RateLimiter.status(:limiter, "user:1",
          algorithm: :token_bucket,
          capacity: 100,
          refill_rate: 10
        )
  """
  @spec status(GenServer.name(), String.t(), keyword()) :: info()
  def status(limiter, key, opts) do
    {:ok, info} = peek(limiter, key, opts)
    info
  end

  @doc """
  Resets the rate limit for a specific key.

  ## Examples

      :ok = Philiprehberger.RateLimiter.reset(:limiter, "user:1")
  """
  @spec reset(GenServer.name(), String.t()) :: :ok
  def reset(limiter, key) do
    Server.reset(limiter, key)
  end

  @doc """
  Resets all rate limits.

  ## Examples

      :ok = Philiprehberger.RateLimiter.reset_all(:limiter)
  """
  @spec reset_all(GenServer.name()) :: :ok
  def reset_all(limiter) do
    Server.reset_all(limiter)
  end
end
