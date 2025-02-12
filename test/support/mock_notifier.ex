defmodule SQLertTest.MockNotifier do
  @behaviour SQLert.Notifier

  def start_link do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def get_alerts do
    Agent.get(__MODULE__, & &1)
  end

  def clear do
    Agent.update(__MODULE__, fn _ -> [] end)
  end

  @impl true
  def deliver(alert) do
    Agent.update(__MODULE__, &[alert | &1])
    :ok
  end
end
