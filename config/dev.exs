use Mix.Config

config :logger, level: :debug

config :boringbot, bots: [
  %{:server => "irc.mozilla.org", :port => 6667,
    :nick => "boringbot-dev",
    :user => "boringbot-dev",
    :pass => "XXX",
    :name => "Bors-NG IRC bot",
    :channel => "##bors-test"}
]

config :boringbot, http: [
  port: 4000,
  webhook_secret: nil,
  webhook_to: "boringbot-dev"
]
