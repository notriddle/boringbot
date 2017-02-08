defmodule Boringbot.Bot.Commands do
  @github Application.get_env(:boringbot, :github)

  require Logger

  def msg(_sender, _message) do
    []
  end

  def group(sender, message) do
    [
      group_issues(sender, message),
    ]
  end

  @doc """
  Build a list of responses for the issues mentioned in this message.
  """
  @spec group_issues(binary, binary) :: list
  def group_issues(_sender, message) do
    message
    |> parse_issues()
    |> Enum.map(fn issue ->
      with(url <- url_issue(issue),
           {:ok, %{body: body, status_code: 200}} <- HTTPoison.get(url),
           {:ok, json} <- Poison.decode(body),
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

  @doc "Get a description from an issue JSON."
  @spec format_issue(%{bitstring => any}) :: bitstring
  def format_issue(%{
    "title" => title,
    "number" => number,
    "state" => state,
    "pull_request" => %{"html_url" => url}}) do
    {:ok, "PR \##{number} [#{state}]: #{title} - #{url}"}
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
      iex> Boringbot.Bot.Commands.parse_issues("#12 is annoying, as are £13 and bors-ng/starters#14")
      [{"bors-ng/bors-ng", "12"}, {"bors-ng/bors-ng", "13"}, {"bors-ng/starters", "14"}]
  """
  @spec parse_issues(binary) :: [{binary, binary}]
  def parse_issues(message) do
    local_issues = ~R{(?:\W|^)(?:#|£)(\d+)}
    |> Regex.scan(message)
    |> Enum.map(fn [_, issue] -> {@github[:repo], issue} end)
    foreign_issues = ~R{(?:\W|^)([a-zA-Z0-9\-_]+/[a-zA-Z0-9\-_]+)(?:#|£)(\d+)}
    |> Regex.scan(message)
    |> Enum.map(fn [_, repo, issue] -> {repo, issue} end)
    local_issues ++ foreign_issues
  end
end