use Mix.Config

config :logger, level: :debug

config :boringbot, bots: [
  %{:server => "irc.digibase.ca", :port => 6667,
    :nick => "boringbot-dev",
    :user => "boringbot-dev",
    :pass => "",
    :name => "FSTDT IRC bot",
    :channels => ["#fstdt-dev"]}
]

config :boringbot, http: [
  port: 4000,
  webhook_secret: nil,
  webhook_to: "#fstdt-dev"
]
