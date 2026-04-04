# philiprehberger_rate_limiter

[![Tests](https://github.com/philiprehberger/ex-rate-limiter/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/ex-rate-limiter/actions/workflows/ci.yml)
[![Hex Version](https://img.shields.io/hexpm/v/philiprehberger_rate_limiter.svg)](https://hex.pm/packages/philiprehberger_rate_limiter)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/ex-rate-limiter)](https://github.com/philiprehberger/ex-rate-limiter/commits/main)

In-process rate limiter with token bucket and sliding window algorithms

## Requirements

- Elixir >= 1.14
- OTP >= 25

## Installation

Add to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:philiprehberger_rate_limiter, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Usage

Add the rate limiter to your supervision tree:

```elixir
children = [
  {Philiprehberger.RateLimiter, name: :my_limiter}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Then check rate limits anywhere in your application:

```elixir
case Philiprehberger.RateLimiter.check(:my_limiter, "user:123",
       algorithm: :token_bucket,
       capacity: 100,
       refill_rate: 10
     ) do
  {:ok, info} ->
    # Request allowed, info.remaining tokens left
    process_request()

  {:error, info} ->
    # Rate limited, retry in info.retry_after milliseconds
    {:error, :rate_limited}
end
```

### Token Bucket

Best for APIs that allow short bursts above the average rate. Tokens refill continuously at a fixed rate.

```elixir
{:ok, %{remaining: 99, limit: 100, reset_in: 1000}} =
  Philiprehberger.RateLimiter.check(:my_limiter, "user:123",
    algorithm: :token_bucket,
    capacity: 100,
    refill_rate: 10,
    cost: 1
  )
```

### Sliding Window

Best for strict request counting per time window. Resets when the window expires.

```elixir
{:ok, %{remaining: 59, limit: 60, reset_in: 58000}} =
  Philiprehberger.RateLimiter.check(:my_limiter, "ip:1.2.3.4",
    algorithm: :sliding_window,
    limit: 60,
    window: 60_000
  )
```

### Peeking Without Consuming

Check the current status without consuming a token:

```elixir
{:ok, %{remaining: 45, limit: 100}} =
  Philiprehberger.RateLimiter.peek(:my_limiter, "user:123",
    algorithm: :token_bucket,
    capacity: 100,
    refill_rate: 10
  )
```

### Resetting Limits

```elixir
# Reset a single key
:ok = Philiprehberger.RateLimiter.reset(:my_limiter, "user:123")

# Reset all keys
:ok = Philiprehberger.RateLimiter.reset_all(:my_limiter)
```

## API

| Function | Description |
|----------|-------------|
| `start_link(opts)` | Start the rate limiter process. Requires `:name` option |
| `check(limiter, key, opts)` | Check and consume from the rate limit. Returns `{:ok, info}` or `{:error, info}` |
| `peek(limiter, key, opts)` | Check status without consuming. Returns `{:ok, info}` |
| `status(limiter, key, opts)` | Get status as a plain map |
| `reset(limiter, key)` | Reset rate limit for a specific key |
| `reset_all(limiter)` | Reset all rate limits |

### Options

| Option | Algorithm | Description |
|--------|-----------|-------------|
| `:algorithm` | Both | `:token_bucket` or `:sliding_window` (required) |
| `:capacity` | Token bucket | Maximum number of tokens (required) |
| `:refill_rate` | Token bucket | Tokens added per second (required) |
| `:cost` | Token bucket | Tokens consumed per check (default: 1) |
| `:limit` | Sliding window | Maximum requests per window (required) |
| `:window` | Sliding window | Window size in milliseconds (required) |

## Development

```bash
mix deps.get
mix compile --warnings-as-errors
mix format --check-formatted
mix test
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/ex-rate-limiter)

🐛 [Report issues](https://github.com/philiprehberger/ex-rate-limiter/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/ex-rate-limiter/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
