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
  end

  finally do
    GenServer.stop(@session_name)
    GenServer.stop(@port_name)
  end

  let :unpacked_message, do: [1,0,nil, "message"]
  let :packed_message, do: unpacked_message |> Msgpax.pack!  |> IO.iodata_to_binary

  it "calls session with unpacked msgpax message" do
    send_data_from_port(packed_message)

    expect_unpacked_message_received
  end

  defp send_data_from_port(data) do
    send @port_name, {:port, {:data, data}}
  end

  defp expect_unpacked_message_received do
    receive do
      {:data, data} -> expect(data).to eq(unpacked_message)
    after
      100 -> raise "data is not received"
    end
  end
end
