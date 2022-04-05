defmodule MessagePack.RPC.TestSession do
  @moduledoc "For tests only"

  def dispatch_data(_session, unpacked_data) do
    send SpecRunner, {:data, unpacked_data}
  end
end
