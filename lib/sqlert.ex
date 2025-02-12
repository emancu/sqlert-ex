defmodule SQLert do
  @version Mix.Project.config()[:version]

  @moduledoc """
  SQLert allows you to create self-contained alert modules that monitor your database
  by running SQL queries at defined schedule.

  ## Overview

  SQLert automatically discovers and runs alerts when your application starts.
  You can also control alerts at runtime:

  SQLert allows you to define alerts that:
    * Run SQL queries at regular intervals
    * Check for specific conditions in your database
    * Trigger notifications when conditions are met


   ## Core Components

    * `SQLert.Alert`    - Behaviour for defining your alerts
    * `SQLert.Notifier` - Behaviour for implementing notification channels

  """

  @doc """
  Returns the version of SQLert.
  """
  def version, do: @version

  @doc """
  Returns a list of all discoverable alerts.

  Every module defined in the scope of the application implementing
  the `SQLert.Alert` behaviour, it will be considered _discoverable_.

  ## Examples

      iex> SQLert.discoverable_alerts()
      [SQLertTest.DisabledAlert, SQLertTest.EnabledAlert]
  """
  @spec discoverable_alerts() :: [module()]
  def discoverable_alerts do
    :code.all_available()
    |> Enum.map(&to_module/1)
    |> Enum.filter(&alert_module?/1)
    |> Enum.sort()
  end

  defp to_module({module_charlist, _, _}),
    do: module_charlist |> List.to_string() |> String.to_atom()

  defp alert_module?(module),
    do: module.module_info(:attributes) |> Keyword.has_key?(:sqlert)

  @doc """
  Returns a list of running alerts.
  """
  @spec running_alerts() :: [{module(), pid()}]
  def running_alerts do
    DynamicSupervisor.which_children(SQLert.AlertSupervisor)
    |> Enum.map(fn {_, _pid, _, [module]} -> module end)
    |> Enum.filter(&alert_module?/1)
    |> Enum.sort()
  end
end
