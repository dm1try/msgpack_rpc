defmodule MessagePack.Transports.Port do
  use GenServer

  alias MessagePack.RPC.Session

  @default_port_settings [:stream, :binary]

  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts ++ [name: __MODULE__])
  end

  def init(args) do
    link = Keyword.get(args, :link) || raise "link is required"
    session = Keyword.get(args, :session) || raise "session is required"
    settings = Keyword.get(args, :settings, [])

    port = Port.open(link, settings ++ @default_port_settings)

    {:ok, %{port: port, rest_data: <<>>, session: session}} end

  def write_data(transport, data) do
    GenServer.call(transport, {:write_data, data})
  end

  def handle_call({:write_data, data}, _from, state) do
    packed_data = Msgpax.pack!(data)
    Port.command state.port, packed_data
    {:reply, :ok, state}
  end

  def handle_info({_port, {:data, data}}, state) do
    {unpacked_data, rest} = Msgpax.unpack_slice!(state.rest_data <> data)

    if unpacked_data do
      Session.dispatch_data(state.session, unpacked_data)
    end

    state = %{state | rest_data: rest}

    {:noreply, state}
  end
end

