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

  post "/webhook/github" do
    send_issue = case get_req_header(conn, "x-github-event") do
      ["issues"] ->
        case conn.body_params["action"] do
          "opened" -> conn.body_params["issue"]
          "reopened" -> conn.body_params["issue"]
          "closed" -> conn.body_params["issue"]
          _ -> nil
        end
      ["pull_request"] ->
        pull_request = conn.body_params["pull_request"]
        issue = Map.put(pull_request, "pull_request", pull_request)
        case conn.body_params["action"] do
          "opened" -> issue
          "reopened" -> issue
          "closed" -> issue
          _ -> nil
        end
      _ ->
        nil
    end

    unless is_nil send_issue do
      :ok = GenServer.call(@bot, {:webhook, :issue, send_issue})
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
