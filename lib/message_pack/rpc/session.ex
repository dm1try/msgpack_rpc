defmodule MessagePack.RPC.Session do
  use GenServer

  alias MessagePack.RPC.Message
  @transport Application.get_env(:msgpack_rpc, :transport) || MessagePack.Transports.Port

  require Logger

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    method_handler = Keyword.get(args, :method_handler) || raise "method handler is required"
    transport = Keyword.get(args, :transport) || raise "transport is required"
    requests_table = :ets.new(:requests_registry, [])

    {:ok, %{last_request_id: 0,
      method_handler: method_handler,
      transport: transport,
      requests_table: requests_table,
      handler_refs: []}}
  end

  # Client API
  def call(session, method, params, timeout \\ 5000) do
    message_id = GenServer.call(session, {:call, method, params})
    Logger.debug "calling for #{method} with #{inspect params}, message_id: #{message_id}"

    receive do
      {:call_result, ^message_id, result} -> result
    after timeout
    -> {:error, :timeout}
    end
  end

  def notify(session, method, params) do
    GenServer.cast(session, {:notify, method, params})
  end

  def dispatch_data(session, data) do
    GenServer.cast(session, {:dispatch_data, data})
  end

  # Server callbacks
  def handle_call({:call, method, params}, from, %{last_request_id: last_request_id, requests_table: requests_table} = state) do
    request_id = last_request_id + 1
    :ets.insert(requests_table, {request_id, from})

    send_message_async state.transport, %Message.Request{id: request_id, method: method, params: params}

    {:reply, request_id, %{state | last_request_id: request_id}}
  end

  def handle_cast({:notify, method, params}, state) do
    send_message_async state.transport, %Message.Notify{method: method, params: params}
    {:noreply, state}
  end

  def handle_cast({:dispatch_data, data}, state) do
    state = try do
      message = Message.build(data)
      session = self
      dispatch_message(message, state, session)
    rescue
      Message.InvalidMessage ->
        Logger.warn("cannot build RPC message from provided data: #{inspect data}")
        state
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, mon_ref, :process, _, :normal},  state) do
    handler_refs =  Enum.reject state.handler_refs, fn({_message_id, monitor_ref})->
      monitor_ref == mon_ref
    end

    {:noreply, %{state | handler_refs: handler_refs}}
  end

  def handle_info({:DOWN, mon_ref, :process, _, error}, %{transport: transport} = state) do
    handler_ref =  Enum.find state.handler_refs, fn({_message_id, monitor_ref})->
      monitor_ref == mon_ref
    end

    if handler_ref do
      message_id = elem(handler_ref, 0)
      message = %Message.ErrorResponse{id: message_id, error: "handler is terminated: #{inspect error}", description: "#{inspect error}"}
      message =  Message.to_raw(message)
      @transport.write_data(transport, message)
    end

    {:noreply, state}
  end

  defp send_message_async(transport, message) do
    spawn fn ->
      message = Message.to_raw(message)
      @transport.write_data(transport, message)
    end
  end

  defp dispatch_message(%Message.Response{id: message_id} = message, state, _session) do
    spawn fn ->
      Logger.debug "response message #{inspect message}"

      case :ets.lookup(state.requests_table, message_id) do
        [] -> nil
        [{^message_id, {cliend_pid, _ref}}] -> send(cliend_pid, {:call_result, message_id, {:ok, message.result}})
      end
    end
    state
  end

  defp dispatch_message(%Message.ErrorResponse{id: message_id} = message, state, _session) do
    spawn fn ->
      Logger.debug "error message #{inspect message}"

      case :ets.lookup(state.requests_table, message_id) do
        [] -> nil
        [{^message_id, {cliend_pid, _ref}}] -> send(cliend_pid, {:call_result, message_id, {:error, message.error}})
      end
    end
    state
  end

  defp dispatch_message(%Message.Request{method: method, params: params} = message, %{method_handler: method_handler, transport: transport} = state, session) do
    {_pid, monitor_ref} = spawn_monitor fn ->
      Logger.debug "dispatch request #{inspect message}"
      call_result = apply(method_handler, :on_call, [session, method, params])

      message = case call_result do
        {:ok, result} ->
          %Message.Response{id: message.id, result: result}
        {:error, :no_method} ->
          %Message.ErrorResponse{id: message.id, error: 0x01 , description: "no such method"}
        {:error, :bad_args} ->
          %Message.ErrorResponse{id: message.id, error: 0x02, description: "bad args"}
        {:error, something} ->
          %Message.ErrorResponse{id: message.id, error: something, description: something}
      end

      message =  Message.to_raw(message)
      @transport.write_data(transport, message)
    end

    %{state | handler_refs: state.handler_refs ++ [{message.id, monitor_ref}]}
  end

  defp dispatch_message(%Message.Notify{} = message, %{method_handler: method_handler} = state, session) do
    spawn fn ->
      Logger.debug "dispatch notify #{inspect message}"

      apply(method_handler, :on_notify, [session, message.method, message.params])
    end

    state
  end
end
