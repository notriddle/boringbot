use Mix.Config

config :logger, level: :debug

config :boringbot, bots: []

config :boringbot, http: [
  webhook_secret: "X",
  webhook_to: {0, "#bors"}
]
