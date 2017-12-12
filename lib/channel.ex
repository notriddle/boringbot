defmodule Boringbot.Bot.Channel do
  @moduledoc """
  A server that speaks IRC with a channel.
  It delegates messages to the Commands module.
  """

  use GenServer
  require Logger

  @message_limit 5

  defmodule Config do
    @moduledoc """
    A struct definition for connecting boringbot to an IRC channel.
    """
    defstruct channel: nil,
              client:  nil,
              nick:    nil

    def from_params(params) when is_map(params) do
      Enum.reduce(params, %Config{}, fn {k, v}, acc ->
        case Map.has_key?(acc, k) do
          true  -> Map.put(acc, k, v)
          false -> acc
        end
      end)
    end
  end

  alias ExIrc.Client
  alias ExIrc.SenderInfo
  alias Boringbot.Bot

  def start_link(params) when is_map(params) do
    config = Config.from_params(params)
    GenServer.start_link(__MODULE__, [config], name: String.to_atom(params.channel))
  end

  def init([config]) do
    Logger.debug "Joining #{config.channel}.."
    Client.join config.client, config.channel
    {:ok, config}
  end

  def handle_info(:joined, config) do
    Logger.debug "Joined"
    {:noreply, config}
  end
  def handle_info({:names_list, names_list}, config) do
    names = String.split(names_list, " ", trim: true)
            |> Enum.map(fn name -> " #{name}\n" end)
    Logger.info "Users logged in to #{config.channel}:\n#{names}"
    {:noreply, config}
  end
  def handle_info(
    {:received, msg, %SenderInfo{:nick => nick}},
    config) do
    Logger.info "#{nick} from #{config.channel}: #{msg}"
    handle_command(:group, nick, msg)
    {:noreply, config}
  end
  def handle_info(:left, config) do
    Logger.info "left"
    {:stop, :disconnected, config}
  end
  def handle_info({:'DOWN', _, :process, pid, {message, _stack}}, config) do
    do_reply(config, "[crash] #{inspect(pid)} - #{inspect(message)}")
    {:noreply, config}
  end
  # Catch-all for messages you don't care about
  def handle_info(_msg, config) do
    {:noreply, config}
  end

  def handle_call({:webhook, :issue, json}, _from, config) do
    {:ok, msg} = Bot.Commands.format_issue(json)
    Logger.info "Webhook notice: #{json["number"]}"
    Client.msg(config.client, :notice, config.channel, msg)
    {:reply, :ok, config}
  end
  def handle_call({:do_reply, msg}, _from, config) do
    do_reply(config, msg)
    {:reply, :ok, config}
  end

  @spec handle_command(:msg | :group, binary, binary) :: :ok
  defp handle_command(type, nick, msg) do
    bot = self()
    {pid, _} = Process.spawn(fn ->
      msg = apply(Bot.Commands, type, [nick, msg])
      GenServer.call(bot, {:do_reply, msg})
    end, [:monitor])
    :timer.kill_after(:timer.seconds(10), pid)
  end

  defp do_reply(_config, _messages, n \\ 0)
  defp do_reply(_, [], n) do
    n
  end
  defp do_reply(
    %Config{client: client, channel: channel},
    _msg,
    n
  ) when n > @message_limit do
    Logger.info("Truncated")
    Client.msg(client, :privmsg, channel, "⚠ truncated message ⚠")
    n + 1
  end
  defp do_reply(config, [a], n) do
    do_reply(config, a, n)
  end
  defp do_reply(config, [a | b], n) do
    n = do_reply(config, a, n)
    if n > @message_limit do
      n
    else
      do_reply(config, b, n)
    end
  end
  defp do_reply(
    %Config{client: client, channel: channel},
    msg,
    n
  ) when is_binary(msg) do
    Logger.info("Send: #{msg}")
    Client.msg(client, :privmsg, channel, msg)
    n + 1
  end
end
