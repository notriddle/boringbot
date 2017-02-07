# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :boringbot, :github,
  api: "https://api.github.com",
  repo: "bors-ng/bors-ng"

import_config "#{Mix.env}.exs"
