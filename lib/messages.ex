defmodule Boringbot.Messages do
  @moduledoc """
  Delayed messages.
  """

  def start_link do
    Agent.start_link(fn -> %{} end, name: Boringbot.Messages)
  end

  @spec add_message(binary, binary, binary) :: :ok
  def add_message(to, from, contents) do
    Agent.update Boringbot.Messages, fn messages ->
      tail = case messages[to] do
        nil -> []
        list -> list
      end
      Map.put(messages, to, [ {from, contents} | tail ])
    end
  end

  @spec get_messages(binary) :: [{binary, binary}]
  def get_messages(to) do
    Agent.get_and_update Boringbot.Messages, fn messages ->
      Map.pop(messages, to, [])
    end
  end

end
