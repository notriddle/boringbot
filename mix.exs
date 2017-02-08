defmodule Boringbot.Mixfile do
  use Mix.Project

  def project do
    [app: :boringbot,
     version: "0.0.2",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
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
      {:distillery, "~> 1.0"},
      {:edeliver, "~> 1.4.0"},
    ]
  end
end
