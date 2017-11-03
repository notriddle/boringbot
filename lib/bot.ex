defmodule Boringbot.Bot do
  @moduledoc """
  A server that speaks IRC with a number of channels.
  It delegates messages to the Commands module.
  """

  use GenServer
  require Logger

  defmodule Config do
    @moduledoc """
    A struct definition for connecting boringbot to an IRC server.
    """
    defstruct server:   nil,
              port:     nil,
              pass:     nil,
              nick:     nil,
              user:     nil,
              name:     nil,
              channels: nil,
              channel_pids: %{},
              client:   nil

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
    GenServer.start_link(__MODULE__, [config], name: String.to_atom(config.name))
  end

  def init([config]) do
    # Start the client and handler processes,
    # the ExIrc supervisor is automatically started when your app runs
    {:ok, client}  = ExIrc.start_client!()

    # Register the event handler with ExIrc
    Client.add_handler client, self()

    # Connect and logon to a server, join the channels and send a simple message
    Logger.debug "Connecting to #{config.server}:#{config.port}"
    Client.connect! client, config.server, config.port

    {:ok, %Config{config | :client => client}}
  end

  def handle_info({:connected, server, port}, config) do
    Logger.debug "Connected to #{server}:#{port}"
    Logger.debug "Logging in to #{server}:#{port} as #{config.nick}.."
    Client.logon(
      config.client,
      config.pass,
      config.nick,
      config.user,
      config.name)
    {:noreply, config}
  end
  def handle_info(:logged_in, config) do
    Logger.debug "Logged in to #{config.server}:#{config.port}"
    channel_pids = config.channels
    |> Enum.map(fn channel ->
      {:ok, pid} = Bot.Channel.start_link(%{nick: config.nick, channel: channel, client: config.client})
      {channel, pid}
    end)
    |> Map.new()
    {:noreply, %Config{config| :channel_pids => channel_pids}}
  end
  def handle_info(:disconnected, config) do
    Logger.debug "Disconnected from #{config.server}:#{config.port}"
    {:stop, :disconnected, config}
  end
  def handle_info({:joined, channel}, config) do
    Logger.debug "Joined #{channel}"
    send(config.channel_pids[channel], :joined)
    {:noreply, config}
  end
  def handle_info({:names_list, channel, names_list}, config) do
    send(config.channel_pids[channel], {:names_list, names_list})
    {:noreply, config}
  end
  def handle_info(
    {:received, msg, sender_info, channel},
    config) do
    send(config.channel_pids[channel], {:received, msg, sender_info})
    {:noreply, config}
  end
  def handle_info({:received, msg, %SenderInfo{:nick => nick}}, config) do
    Logger.warn "#{nick}: #{msg}"
    handle_command(nick, msg)
    {:noreply, config}
  end
  # Catch-all for messages you don't care about
  def handle_info(_msg, config) do
    {:noreply, config}
  end

  def handle_call({:do_reply, msg, nick}, _from, config) do
    do_reply(config, msg, nick)
    {:reply, :ok, config}
  end

  def terminate(_, config) do
    # Quit and close the underlying client connection
    # when the process is terminating
    Enum.each(config.channel_pids, fn {_channel, pid} ->
      send(pid, :left)
    end)
    Client.quit config.client, "Goodbye, cruel world."
    Client.stop! config.client
    :ok
  end

  @spec handle_command(binary, binary) :: :ok
  defp handle_command(nick, msg) do
    bot = self()
    {pid, _} = Process.spawn(fn ->
      msg = Bot.Commands.msg(nick, msg)
      GenServer.call(bot, {:do_reply, msg, nick})
    end, [:monitor])
    :timer.kill_after(:timer.seconds(10), pid)
  end

  defp do_reply(_, [], _) do
    :ok
  end
  defp do_reply(config, [a], nick) do
    do_reply(config, a, nick)
  end
  defp do_reply(config, [a | b], nick) do
    do_reply(config, a, nick)
    do_reply(config, b, nick)
  end
  defp do_reply(
    %Config{client: client},
    msg,
    nick
  ) when is_binary(msg) do
    Logger.info("Send: #{msg}")
    Client.msg(client, :privmsg, nick, msg)
  end
end
