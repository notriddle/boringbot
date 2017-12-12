defmodule Boringbot.Bot.Channel do
  @moduledoc """
  A server that speaks IRC with a channel.
  It delegates messages to the Commands module.
  """

  use GenServer
  require Logger

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
    do_reply(config, truncate(msg))
    {:reply, :ok, config}
  end

  @spec handle_command(:msg | :group, binary, binary) :: :ok
  defp handle_command(type, nick, msg) do
    bot = self()
    {pid, _} = Process.spawn(fn ->
      msg = apply(Bot.Commands, type, [nick, msg])
      GenServer.call(bot, {:do_reply, truncate(msg)})
    end, [:monitor])
    :timer.kill_after(:timer.seconds(10), pid)
  end

  @doc """
  Keep the user from pushing an unbounded number of messages into the IRC channel.

      iex> Channel.truncate(["do", "re", "mi", "fa", "so", "la", "ti", "do"])
      ["do", "re", "mi", "fa", "so", "⚠ truncated output ⚠"]
      iex> Channel.truncate(["1", "2", "3", "4", "5"])
      ["1", "2", "3", "4", "5"]
  """
  def truncate([a, b, c, d, e, f, _]) do
    [a, b, c, d, e, "⚠ truncated output ⚠"]
  end
  def truncate(list) do
    list
  end

  defp do_reply(_, []) do
    :ok
  end
  defp do_reply(config, [a]) do
    do_reply(config, a)
  end
  defp do_reply(config, [a | b]) do
    do_reply(config, a)
    do_reply(config, b)
  end
  defp do_reply(
    %Config{client: client, channel: channel},
    msg
  ) when is_binary(msg) do
    Logger.info("Send: #{msg}")
    Client.msg(client, :privmsg, channel, msg)
  end
end
