defmodule Boringbot.Http do
  use Plug.Router

  @http Application.get_env(:boringbot, :http)
  @bot String.to_atom(@http[:webhook_to])

  plug Boringbot.Http.GithubWebhookParser, secret: @http[:webhook_secret]
  plug :match
  plug :dispatch

  post "/webhook/github" do
    case get_req_header(conn, "x-github-event") do
      ["issues"] ->
        run = case conn.body_params["action"] do
          "opened" -> true
          "reopened" -> true
          "closed" -> true
          _ -> false
        end
        :ok = if run do
          GenServer.call(
            @bot,
            {:webhook, :issue, conn.body_params["issue"]})
        else
          :ok
        end
      _ -> :ok
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
