defmodule Boringbot.Http do
  @moduledoc """
  Plug/Cowboy HTTP server for receiving GitHub webhooks
  """

  use Plug.Router

  @http Application.get_env(:boringbot, :http)
  @bot String.to_atom(@http[:webhook_to])

  plug Boringbot.Http.GithubWebhookParser, secret: @http[:webhook_secret]
  plug :match
  plug :dispatch

  def issue_action?("opened"), do: true
  def issue_action?("reopened"), do: true
  def issue_action?("closed"), do: true
  def issue_action?(_), do: false

  def issue(%{"issue" => issue}), do: issue
  def issue(%{"pull_request" => issue}), do: issue
  def issue(_), do: false

  post "/webhook/github" do
    issue = issue(conn.body_params)
    action? = issue_action?(conn.body_params["action"])
    if issue && action? do
      GenServer.call(@bot, {:webhook, :issue, issue})
    else
      :ok
    end

    send_resp(conn, 200, "")
  end

  match _ do
    send_resp(conn, 404, "")
  end

  def start_link do
    Plug.Adapters.Cowboy.http(__MODULE__, [], port: @http[:port])
  end
end
