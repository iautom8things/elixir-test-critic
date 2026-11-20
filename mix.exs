defmodule TestCritic.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/iautom8things/elixir-test-critic"

  def project do
    [
      app: :test_critic,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description:
        "Credo checks for flaky Elixir tests, weak assertions, and unstable build configuration.",
      package: package(),
      source_url: @source_url,
      docs: [main: "readme", extras: ["README.md"], source_ref: "v#{@version}"],
      aliases: [credo: ["compile", "credo"]],
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:prod), do: ["lib/test_critic/credo"]
  defp elixirc_paths(_env), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["iautom8things"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib/test_critic/credo mix.exs README.md LICENSE)
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", runtime: false},
      {:yaml_elixir, "~> 2.9", only: [:dev, :test]},
      {:ex_doc, "~> 0.38.0", only: :dev, runtime: false}
    ]
  end
end
