defmodule Philiprehberger.RateLimiter.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/philiprehberger/ex-rate-limiter"

  def project do
    [
      app: :philiprehberger_rate_limiter,
      version: @version,
      elixir: ">= 1.14.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Philiprehberger.RateLimiter",
      description: "In-process rate limiter with token bucket and sliding window algorithms",
      source_url: @source_url,
      homepage_url:
        "https://philiprehberger.com/open-source-packages/elixir/philiprehberger_rate_limiter",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Homepage" =>
          "https://philiprehberger.com/open-source-packages/elixir/philiprehberger_rate_limiter"
      },
      maintainers: ["Philip Rehberger"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "Philiprehberger.RateLimiter",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
