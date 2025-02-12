defmodule SQLertTest.DisabledAlert do
  @moduledoc false
  use SQLert.Alert,
    schedule: "* 1 * * *",
    enabled: false

  @impl true
  def query, do: "SELECT COUNT(*) FROM users"

  @impl true
  def handle_result(_) do
    {:skip, %{}}
  end

  @impl true
  def notifiers, do: []
end
