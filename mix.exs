defmodule SQLert.MixProject do
  use Mix.Project

  @version "0.0.2"
  @source_url "https://github.com/emancu/sqlert-ex"

  def project do
    [
      app: :sqlert,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "SQL-based alerts for Elixir applications"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SQLert.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:crontab, "~> 1.1"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "SQLert",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      maintainers: ["Emiliano Mancuso"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib LICENSE mix.exs README.md .formatter.exs)
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
