defmodule MessagePack.RPC.SessionSpec do
  use ESpec
  alias MessagePack.RPC.{Session, Message}
  alias MessagePack.Transports.Stub, as: TestTransport

  @session_name NullSession
  @port_name NullPort

  defmodule TestHandler do
     def on_call(_session, "failure", _params) do
       send ESpec.Runner, :on_terminate
       Process.exit(self, "terminated in handler")
     end

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
    {:ok, port_pid} = TestTransport.start_link([session: @session_name], [name: @port_name])
    {:ok, session_pid} = MessagePack.RPC.Session.start_link(
      [method_handler: TestHandler , transport: @port_name],
      [name: @session_name]
    )

    {:shared, port_pid: port_pid, session_pid: session_pid}
  end

  finally do
    TestTransport.stop(shared.port_pid)
    GenServer.stop(shared.session_pid)
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

  context "handler is terminated" do
    let :message_that_leads_to_failure, do: %Message.Request{id: 1, method: "failure", params: []} |> Message.to_raw
    let :last_message, do: List.last(TestTransport.messages(shared.port_pid))

    it "sends error respones if handler is terminated" do
      Session.dispatch_data(@session_name, message_that_leads_to_failure)

      :timer.sleep 50

      expect(last_message).to be_truthy
      expect(Message.build(last_message).error).to have("handler is terminated")
    end
  end
end
