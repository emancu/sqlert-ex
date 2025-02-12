defmodule SQLertTest.MockRepo do
  @moduledoc false
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{result: [[0]]}}
  end

  def set_result(result) do
    GenServer.call(__MODULE__, {:set_result, result})
  end

  def query!(_query) do
    GenServer.call(__MODULE__, :get_result)
  end

  def all(_query) do
    %{rows: [res]} = GenServer.call(__MODULE__, :get_result)

    res
  end

  def handle_call({:set_result, result}, _from, state) do
    {:reply, :ok, %{state | result: result}}
  end

  def handle_call(:get_result, _from, state) do
    {:reply, %{rows: state.result}, state}
  end
end
