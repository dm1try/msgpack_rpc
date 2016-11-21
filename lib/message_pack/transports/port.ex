defmodule MessagePack.Transports.Port do
  use GenServer

  @session Application.get_env(:msgpack_rpc, :session) || MessagePack.RPC.Session

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
    rest = dispatch(state.session, state.rest_data <> data)
    state = %{state | rest_data: rest}

    {:noreply, state}
  end

  defp dispatch(session, data) do
    case  Msgpax.unpack_slice(data) do
      {:error, :incomplete} -> data
      {:ok, "", rest} -> rest
      {:ok, unpacked_data, rest} ->
        @session.dispatch_data(session, unpacked_data)
        dispatch(session, rest)
    end
  end
end

