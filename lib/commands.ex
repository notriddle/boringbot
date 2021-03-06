defmodule Boringbot.Bot.Commands do
  @moduledoc """
  Text command router and implementations.
  """

  @github Application.get_env(:boringbot, :github)

  @type response :: [response] | binary

  require Logger

  def msg(sender, message) do
    [
      cmd_line(sender, message)
    ]
  end

  def group(sender, message) do
    [
      group_issues(sender, message),
      get_messages(sender),
      cmd_start(sender, message),
    ]
  end

  @doc """
  Conditionally dispatch based on the command prefix.

      iex> Boringbot.Bot.Commands.cmd_start("me", "!roll over")
      "🙃🙂💨"
      iex> Boringbot.Bot.Commands.cmd_start("me", "! roll over")
      "🙃🙂💨"
      iex> Boringbot.Bot.Commands.cmd_start("me", "boringbot: roll over")
      "🙃🙂💨"
  """
  @spec cmd_start(binary, binary) :: response
  def cmd_start(sender, "!"), do: cmd_ping(sender)
  def cmd_start(sender, "!" <> line), do: cmd_line(sender, line)
  def cmd_start(sender, "boringbot:" <> line), do: cmd_line(sender, line)
  def cmd_start(sender, "boringbot," <> line), do: cmd_line(sender, line)
  def cmd_start(sender, "boringbot " <> line), do: cmd_line(sender, line)
  def cmd_start(_sender, _message), do: []

  @doc """
  Dispatch based on the first part of a command line.
  """
  @spec cmd_line(binary, binary) :: response
  def cmd_line(sender, " " <> command), do: cmd_line(sender, command)
  def cmd_line(sender, "tell " <> args), do: cmd_tell(sender, args)
  def cmd_line(sender, "ask " <> args), do: cmd_tell(sender, args)
  def cmd_line(sender, "ping"), do: cmd_ping(sender)
  def cmd_line(sender, "roll over"), do: "🙃🙂💨"
  def cmd_line(sender, "roll"), do: cmd_roll(sender, "1d6")
  def cmd_line(sender, "roll dice"), do: cmd_roll(sender, "2d6")
  def cmd_line(sender, "roll " <> args), do: cmd_roll(sender, args)
  def cmd_line(_sender, "calculate " <> args), do: cmd_calc(args)
  def cmd_line(_sender, "calc " <> args), do: cmd_calc(args)
  def cmd_line(_sender, "botsnack"), do: Enum.random(["😋", "🤢", "🍫", "🍪", "🎂", "🍜", "🍣", "🍔", "🍕", "🌯"])
  def cmd_line(_sender, "crash"), do: raise RuntimeError, "explicit crash"
  def cmd_line(sender, "help"), do: cmd_help(sender)
  def cmd_line(_sender, _command), do: []

  @doc """
  Give out a link to boringbot's README.
  """
  def cmd_help(sender), do: sender <> ": https://github.com/notriddle/boringbot"

  @doc """
  Record a tell message.
  """
  @spec cmd_tell(binary, binary) :: binary
  def cmd_tell(sender, args) do
    args
    |> String.trim()
    |> parse_tell("")
    |> do_tell(sender)
  end
  def do_tell({:ok, user, message}, sender) do
    Boringbot.Messages.add_message(user, sender, message)
    sender <> ": ✔ I'll let them know."
  end
  def do_tell({:error, user}, sender) do
    sender <> ~S{: Am I supposed to tell "} <> user <> ~S{"" something?}
  end

  @doc """
  Parse a tell message.
  """
  @spec parse_tell(binary, binary) ::
    {:ok, binary, binary} |
    {:error, binary}
  def parse_tell(" " <> message, user), do: {:ok, user, String.trim(message)}
  def parse_tell(":" <> message, user), do: {:ok, user, String.trim(message)}
  def parse_tell("," <> message, user), do: {:ok, user, String.trim(message)}
  def parse_tell("", user), do: {:error, user}
  def parse_tell(<<c :: 8, args :: binary>>, user) do
    parse_tell(args, <<user :: binary, c :: 8>>)
  end

  @doc """
  Respond to a ping.
  """
  @spec cmd_ping(binary) :: response
  def cmd_ping(sender) do
    [response] = Enum.take_random([
      # sfx
      "pong",
      "boing",
      "doing",
      "doink",
      "boink",
      "ding",
      # tech
      "[ACK]",
      "204 NO CONTENT",
      "ECHO_REPLY",
      "PING REPLY",
      # emoji / emoticon
      "😄",
      ":-)",
      "(-:" ], 1)
    sender <> ": " <> response
  end

  @doc """
  Roll a dice. Also supports putting it in an expression.

      iex> Boringbot.Bot.Commands.cmd_roll("me", "1d1")
      ["me: 🎲 1"]
      iex> Boringbot.Bot.Commands.cmd_roll("me", "1d1-1")
      ["me: 🎲 0"]
      iex> Boringbot.Bot.Commands.cmd_roll("me", "d1")
      ["me: 🎲 1"]
      iex> Boringbot.Bot.Commands.cmd_roll("me", "2d1")
      ["me: 🎲 1", "me: 🎲 1"]
      iex> Boringbot.Bot.Commands.cmd_roll("me", "d1-1")
      ["me: 🎲 0"]
  """
  @spec cmd_roll(binary, binary) :: response
  def cmd_roll(sender, args) do
    {count, sides, expr} = args
    |> String.split(~r/(\s|d)+/)
    |> case do
      ["", sides] ->
        {sides, expr} = Integer.parse(sides)
        {1, sides, expr}
      [count, sides] ->
        {count, ""} = Integer.parse(count)
        {sides, expr} = Integer.parse(sides)
        {count, sides, expr}
      [sides] ->
        {sides, expr} = Integer.parse(sides)
        {1, sides, expr}
    end
    Enum.map(1..count, fn _ ->
      result = Enum.random(1..sides)
      result = cmd_calc("#{result}#{expr}")
      sender <> ": 🎲 " <> to_string(result)
    end)
  end

  @doc """
  Release any messages destined for this user.
  """
  @spec get_messages(binary) :: response
  def get_messages(user) do
    Boringbot.Messages.get_messages(user)
    |> Enum.map(fn {from, contents} ->
      user <> ": [" <> from <> "] " <> contents
    end)
  end

  @doc """
  Build a list of responses for the issues mentioned in this message.
  """
  @spec group_issues(binary, binary) :: response
  def group_issues(_sender, message) do
    message
    |> parse_issues()
    |> Enum.map(fn issue ->
      with(url <- url_issue(issue),
           {:ok, json} <- fetch_issue(url),
           {:ok, group_issue} <- format_issue(json),
           do: {:succeeded, [group_issue, "\n"]})
      |> case do
        {:succeeded, iolist} -> iolist
        err ->
          Logger.debug({issue, err})
          :error
      end
    end)
    |> Enum.filter(&(&1 != :error))
  end

  @spec fetch_issue(binary) :: {:ok, map} | {:error, term}
  def fetch_issue(url) do
    with({:ok, %{body: body, status_code: 200}} <- HTTPoison.get(url),
         {:ok, json} <- Poison.decode(body)) do
        case json do
          %{ "pull_request" => %{ "url" => url }} -> fetch_issue(url)
          json -> {:ok, json}
        end
    end
  end

  @doc """
  Get a description from an issue JSON.

      iex> Boringbot.Bot.Commands.format_issue(%{
      ...>   "title" => "test",
      ...>   "number" => 1,
      ...>   "state" => "open",
      ...>   "html_url" => "h" })
      {:ok, "Issue #1 [open]: test - h"}
      iex> Boringbot.Bot.Commands.format_issue(%{
      ...>   "title" => "test2",
      ...>   "number" => 1,
      ...>   "state" => "closed",
      ...>   "html_url" => "h2" })
      {:ok, "Issue #1 [closed]: test2 - h2"}
      iex> Boringbot.Bot.Commands.format_issue(%{
      ...>   "title" => "test",
      ...>   "number" => 1,
      ...>   "state" => "open",
      ...>   "html_url" => "h",
      ...>   "merged" => false })
      {:ok, "PR #1 [open]: test - h"}
      iex> Boringbot.Bot.Commands.format_issue(%{
      ...>   "title" => "test",
      ...>   "number" => 1,
      ...>   "state" => "open",
      ...>   "html_url" => "h",
      ...>   "merged" => true })
      {:ok, "PR #1 [open/merged]: test - h"}
      iex> Boringbot.Bot.Commands.format_issue(%{
      ...>   "title" => "test",
      ...>   "number" => 1,
      ...>   "state" => "closed",
      ...>   "html_url" => "h",
      ...>   "merged" => true })
      {:ok, "PR #1 [merged]: test - h"}
  """
  @spec format_issue(%{binary => any}) ::
    {:ok, binary} | {:err, :group_issue}
  def format_issue(%{
    "title" => title,
    "number" => number,
    "state" => state,
    "html_url" => url,
    "merged" => merged }) do
    pr_state = case {state, merged} do
      {"closed", true} -> "merged"
      {_, true} -> "open/merged"
      {state, false} -> state
    end
    {:ok, "PR \##{number} [#{pr_state}]: #{title} - #{url}"}
  end
  def format_issue(%{
    "html_url" => url,
    "title" => title,
    "state" => state,
    "number" => number}) do
    {:ok, "Issue \##{number} [#{state}]: #{title} - #{url}"}
  end
  def format_issue(_) do
    {:err, :group_issue}
  end

  @doc """
  Get a URL from an issue parse result.

      iex> Boringbot.Bot.Commands.url_issue({"bors-ng/bors-ng", "13"})
      "https://api.github.com/repos/bors-ng/bors-ng/issues/13"
  """
  def url_issue({repo, number}) do
    "#{@github[:api]}/repos/#{repo}/issues/#{number}"
  end

  @doc """
  Parse out GitHub issue numbers.

      iex> Boringbot.Bot.Commands.parse_issues("I ❤ GitHub")
      []
      iex> Boringbot.Bot.Commands.parse_issues(
      ...>   "#12 is annoying, as are £13 and bors-ng/starters#14")
      [{"notriddle/boringbot", "12"},
       {"notriddle/boringbot", "13"},
       {"bors-ng/starters", "14"}]
      iex> Boringbot.Bot.Commands.parse_issues(
      ...>   "https://github.com/bors-ng/boringbot/issues/6")
      [{"bors-ng/boringbot", "6"}]
      iex> Boringbot.Bot.Commands.parse_issues(
      ...>   "bla https://github.com/bors-ng/boringbot/pull/16 bla")
      [{"bors-ng/boringbot", "16"}]
  """
  @spec parse_issues(binary) :: [{binary, binary}]
  def parse_issues(message) do
    repo_regex = ~s"[a-zA-Z0-9\-_]+/[a-zA-Z0-9\-_\.]+"
    local_issues = ~r"(?:\W|^)(?:#|£)(\d+)"
    |> Regex.scan(message)
    |> Enum.map(fn [_, issue] -> {@github[:repo], issue} end)
    foreign_issues = ~r"(?:\W|^)(#{repo_regex})(?:#|£)(\d+)"
    |> Regex.scan(message)
    |> Enum.map(fn [_, repo, issue] -> {repo, issue} end)
    url_issues = ~r"https://github.com/(#{repo_regex})/(?:issues|pull)/(\d+)"
    |> Regex.scan(message)
    |> Enum.map(fn [_, repo, issue] -> {repo, issue} end)
    local_issues ++ foreign_issues ++ url_issues
  end

  @doc """
  Perform arithmetic.
  See <https://github.com/narrowtux/abacus> for a list of supported operations.
      iex> Boringbot.Bot.Commands.cmd_calc("1+1")
      "2"
      iex> Boringbot.Bot.Commands.cmd_calc("log10(e)/log10(e)")
      "1.0"
      iex> Boringbot.Bot.Commands.cmd_calc("(")
      "Parse failed"
  """
  @spec cmd_calc(binary) :: response
  def cmd_calc(expression) do
    vars = %{
      "pi" => 3.14159265,
      "e"  => 2.71828182,
    }
    expression
    |> Abacus.parse()
    |> case do
      {:ok, syntax} -> Abacus.eval(syntax, vars)
      _ -> {:error, :parse_failed}
    end
    |> case do
      {:ok, result} -> to_string(result)
      {:error, :parse_failed} -> "Parse failed"
      _ -> "Calc failed"
    end
  end
end
