defmodule SQLert.Notifier do
  @moduledoc """
  Behaviour for implementing alert notification delivery.

  ## Example

      defmodule MyApp.SQLerts.SlackNotifier do
        @behaviour SQLert.Notifier

        @impl true
        def deliver(alert) do
          # Send to Slack
          :ok
        end
      end
  """

  @callback deliver(alert :: SQLert.Alert.t()) :: :ok | {:error, term()}
end
