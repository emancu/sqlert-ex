defmodule SQLert.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: SQLert.AlertSupervisor}
    ]

    opts = [strategy: :one_for_one, name: SQLert.Supervisor]

    {:ok, pid} = Supervisor.start_link(children, opts)

    SQLert.discoverable_alerts()
    |> Enum.filter(& &1.enabled?)
    |> Enum.each(&start_alert/1)

    {:ok, pid}
  end

  defp start_alert(alert) do
    {:ok, _} = DynamicSupervisor.start_child(SQLert.AlertSupervisor, alert)
  end
end
