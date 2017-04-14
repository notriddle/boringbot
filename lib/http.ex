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

  def notify_action?("opened"), do: true
  def notify_action?("reopened"), do: true
  def notify_action?("closed"), do: true
  def notify_action?(_), do: false

  def notify_type("issues"), do: :issue
  def notify_type("pull_request"), do: :pull_request
  def notify_type(_), do: nil

  post "/webhook/github" do
    case notify_type(get_req_header(conn, "x-github-event")) do
      nil -> :ok
      notify_type ->
        if notify_action?(conn.body_params["action"]) do
          GenServer.call(@bot, {:webhook, notify_type, conn.body_params})
        else
          :ok
        end
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
