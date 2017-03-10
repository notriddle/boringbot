defmodule Boringbot do
  @moduledoc """
  A basic IRC bot.
  """

  use Application

  alias Boringbot.Bot

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    bots = Application.get_env(:boringbot, :bots)
         |> Enum.map(fn bot -> worker(Bot, [bot]) end)

    children = if is_nil Application.get_env(:boringbot, :http)[:port] do
      bots
    else
      [ worker(Boringbot.Http, []) | bots ]
    end
    children = [ worker(Boringbot.Messages, []) | children ]
    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Boringbot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
