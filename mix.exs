defmodule Shampoo.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/iautom8things/shampoo"

  def project do
    [
      app: :shampoo,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description:
        "Gets the flakes out of your test suite. Credo checks for flaky ExUnit tests, assertions that cannot fail, and unstable build configuration.",
      package: package(),
      source_url: @source_url,
      docs: [
        main: "readme",
        extras: ["README.md"],
        logo: "assets/suds-mark.svg",
        assets: %{"assets" => "assets"},
        source_ref: "v#{@version}"
      ],
      aliases: [credo: ["compile", "credo"]],
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:prod), do: ["lib/shampoo/check"]
  defp elixirc_paths(_env), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["iautom8things"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib/shampoo/check assets/suds.svg assets/suds-mark.svg mix.exs README.md LICENSE)
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
