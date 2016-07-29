defmodule MessagePack.Transports.PortSpec do
  use ESpec

  @port_name TestPort
  @session_name TestSession

  before do
    MessagePack.Transports.Port.start_link(
      [link: {:fd, 3, 3}, session: @session_name],
      [name: @port_name]
    )

    MessagePack.RPC.Session.start_link(
      [method_handler: TestHandler , transport: Port],
      [name: @session_name]
    )

    allow(MessagePack.RPC.Session).to accept(:dispatch_data)
  end

  finally do
    GenServer.stop(@session_name)
    GenServer.stop(@port_name)
  end

  let :unpacked_message, do: [1,0,nil, "message"]
  let :packed_message, do: unpacked_message |> Msgpax.pack!  |> IO.iodata_to_binary

  it "calls session with unpacked msgpax message" do
    send_data_from_port(packed_message)

    expect MessagePack.RPC.Session |> to(
      accepted :dispatch_data, [TestSession, unpacked_message]
    )
  end

  defp send_data_from_port(data) do
    send TestPort, {:port, {:data, data}}
  end
end
