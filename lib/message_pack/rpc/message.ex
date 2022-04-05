defmodule MessagePack.RPC.Message do
  @request  0
  @response 1
  @notify   2

#  @no_method_error 0x01
#  @argument_error  0x02

  defmodule Request,        do: defstruct [:id, :method, :params]
  defmodule Notify,         do: defstruct [:method, :params]

  defmodule Response,       do: defstruct [:id, :result]
  defmodule ErrorResponse,  do: defstruct [:id, :error, :description]

  defmodule InvalidMessage do
    defexception message: "invalid message"
  end

  def build([@request, message_id, method, params]) do
    %Request{id: message_id, method: method, params: params}
  end

  def build([@response, message_id, error, result]) when is_nil(error) do
    %Response{id: message_id, result: result}
  end

  def build([@response, message_id, error, description]) do
    %ErrorResponse{id: message_id, error: error, description: description}
  end

  def build([@notify, method, params]) do
    %Notify{method: method, params: params}
  end

  def build(_) do
    raise InvalidMessage
  end

  def to_raw(%Request{id: message_id, method: method, params: params}) do
    [@request, message_id, method, params]
  end

  def to_raw(%Response{id: message_id, result: result}) do
    [@response, message_id, nil, result]
  end

  def to_raw(%ErrorResponse{id: message_id, error: error}) do
    [@response, message_id, error, ""]
  end

  def to_raw(%Notify{method: method, params: params}) do
    [@notify, method, params]
  end
end
