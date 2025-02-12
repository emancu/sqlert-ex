defmodule SQLertTest.EnabledAlert do
  use SQLert.Alert,
    schedule: "59 * 6 * *",
    enabled: true

  @impl true
  def query, do: "SELECT COUNT(*) FROM users"

  @impl true
  def handle_result([[count]]) when count > 10 do
    {:alert, "Too many users", %{count: count}}
  end

  def handle_result(_) do
    {:skip, %{}}
  end

  @impl true
  def notifiers, do: [SQLertTest.MockNotifier]
end
