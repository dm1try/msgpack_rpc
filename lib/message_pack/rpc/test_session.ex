defmodule MessagePack.RPC.TestSession do
  @moduledoc "For tests only"

  def dispatch_data(_session, unpacked_data) do
    send ESpec.Runner, {:data, unpacked_data}
  end
end
