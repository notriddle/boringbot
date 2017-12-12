defmodule Boringbot.Mixfile do
  use Mix.Project

  def project do
    [app: :boringbot,
     version: "0.6.3",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     name: "Boringbot",
     source_url: "https://github.com/notriddle/boringbot",
     docs: [main: "Boringbot", extras: ["README.md"]]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger],
     mod: {Boringbot, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:exirc, ">= 1.0.0"},
      {:poison, "~> 3.0"},
      {:httpoison, "~> 0.10.0"},
      {:dogma, "~> 0.1", only: [:dev], runtime: false},
      {:dialyxir, "~> 0.4", only: [:dev], runtime: false},
      {:distillery, "~> 1.0"},
      {:edeliver, "~> 1.4.0"},
      {:plug, "~> 1.3.0"},
      {:cowboy, "~> 1.0.0"},
      {:abacus, "~> 0.3.1"},
      {:ex_doc, "~> 0.14", only: :dev},
    ]
  end
end
