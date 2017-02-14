defmodule Boringbot.Bot do
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
    defstruct server:  nil,
              port:    nil,
              pass:    nil,
              nick:    nil,
              user:    nil,
              name:    nil,
              channel: nil,
              client:  nil

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

  def start_link(%{:nick => nick} = params) when is_map(params) do
    config = Config.from_params(params)
    GenServer.start_link(__MODULE__, [config], name: String.to_atom(nick))
  end

  def init([config]) do
    # Start the client and handler processes,
    # the ExIrc supervisor is automatically started when your app runs
    {:ok, client}  = ExIrc.start_client!()

    # Register the event handler with ExIrc
    Client.add_handler client, self()

    # Connect and logon to a server, join a channel and send a simple message
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
    Logger.debug "Joining #{config.channel}.."
    Client.join config.client, config.channel
    {:noreply, config}
  end
  def handle_info(:disconnected, config) do
    Logger.debug "Disconnected from #{config.server}:#{config.port}"
    {:stop, :normal, config}
  end
  def handle_info({:joined, channel}, config) do
    Logger.debug "Joined #{channel}"
    {:noreply, config}
  end
  def handle_info({:names_list, channel, names_list}, config) do
    names = String.split(names_list, " ", trim: true)
            |> Enum.map(fn name -> " #{name}\n" end)
    Logger.info "Users logged in to #{channel}:\n#{names}"
    {:noreply, config}
  end
  def handle_info(
    {:received, msg, %SenderInfo{:nick => nick}, channel},
    config) do
    Logger.info "#{nick} from #{channel}: #{msg}"
    do_reply(config, Bot.Commands.group(nick, msg))
    {:noreply, config}
  end
  def handle_info(
    {:mentioned, msg, %SenderInfo{:nick => nick}, channel},
    config) do
    Logger.warn "#{nick} mentioned you in #{channel}"
    do_reply(config, Bot.Commands.msg(nick, msg))
    {:noreply, config}
  end
  def handle_info({:received, msg, %SenderInfo{:nick => nick}}, config) do
    Logger.warn "#{nick}: #{msg}"
    do_reply(config, Bot.Commands.msg(nick, msg))
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

  def terminate(_, state) do
    # Quit the channel and close the underlying client connection
    # when the process is terminating
    Client.quit state.client, "Goodbye, cruel world."
    Client.stop! state.client
    :ok
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
    Client.msg(client, :privmsg, channel, msg)
  end
end
