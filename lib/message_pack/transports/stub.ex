defmodule MessagePack.Transports.Stub do
  @moduledoc "For tests only"

  def start_link(_args \\ [], opts \\ []) do
    Agent.start_link(fn-> [] end, name: opts[:name])
  end

  def write_data(pid, data) do
    Agent.update(pid, fn(messages) ->
      messages ++ [data]
    end)
  end

  def messages(pid) do
    Agent.get(pid, &(&1))
  end

  def stop(pid) do
    Agent.stop(pid)
  end
end
