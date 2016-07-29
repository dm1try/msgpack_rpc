defmodule MessagePack.RPC.SessionSpec do
  use ESpec
  alias MessagePack.RPC.{Session, Message}

  @session_name NullSession

  defmodule TestHandler do
    def on_call(_session, method, _params) do
      send ESpec.Runner, :on_call_received
      {:ok, method}
    end

    def on_notify(_session, _method, _params) do
      send ESpec.Runner, :on_notify_received
      {:ok, :processed}
    end
  end

  before do
    MessagePack.RPC.Session.start_link(
      [method_handler: TestHandler , transport: NullPort],
      [name: @session_name]
    )
  end

  let :request_message, do: %Message.Request{id: 1, method: "method", params: ["param"]} |> Message.to_raw
  let :notify_message, do: %Message.Notify{method: "method", params: ["param"]} |> Message.to_raw

  it "calls handler on request" do
    Session.dispatch_data(@session_name, request_message)

    receive do
      :on_call_received ->
        :ok
    after
      300 ->
        raise "call handler is not called"
    end
  end

  it "calls handler on notify" do
    Session.dispatch_data(@session_name, notify_message)

    receive do
      :on_notify_received ->
        :ok
    after
      300 ->
        raise "notify handler is not called"
    end
  end
end
