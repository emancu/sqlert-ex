# SQLert

> Monitor your database and trigger alerts based on SQL queries in Elixir

SQLert allows you to create self-contained alert modules that monitor your database by running SQL queries at defined intervals. Perfect for monitoring business metrics, detecting anomalies, or tracking system health.

## Installation

Add `sqlert` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sqlert, "~> 0.1.0"}
  ]
end
```

2. Configure your repo in `config/config.exs`:

      ```elixir
      config :sqlert,
        repo: MyApp.Repo
      ```

  3. Create an alert:

      ```elixir
      defmodule MyApp.Alerts.HighErrorRate do
        use SQLert.Alert,
          interval: :timer.minutes(15)

        @impl true
        def query do
          "SELECT COUNT(*) 
           FROM errors 
           WHERE created_at > NOW() - INTERVAL '1 hour'"
        end

        @impl true
        def handle_result(%{rows: [[count]]}) when count > 100 do
          {:alert, "High error rate detected", %{count: count}}
        end
      end
      ```


       4. Implement a notifier (optional):

      ```elixir
      defmodule MyApp.Alerts.Notifiers.Slack do
        @behaviour SQLert.Notifier

        @impl true
        def deliver(alert) do
          # Send to Slack
          :ok
        end
      end
      ```


## Quick Start


Create your first alert:

```elixir
defmodule MyApp.Alerts.HighErrorRate do
  use SQLert.Behaviour

  @impl true
  def query do
    """
    SELECT COUNT(*) 
    FROM errors 
    WHERE created_at > NOW() - INTERVAL '1 hour'
    """
  end

  @impl true
  def interval, do: :timer.minutes(30)

  @impl true
  def handle_result(%{rows: [[count]]}) when count > 100 do
    # Send to Slack, email, etc.
    notify(:warning, "High error rate detected", %{count: count})
  end
end
```

## Features

- 🔄 Run SQL queries at configurable intervals
- 🎯 Easy to implement custom alert handlers
- 📊 Built-in metrics via Telemetry
- 🔌 Pluggable notification system
- 💪 Process isolation for each alert
- 🧩 Simple integration with external services

## Alert Configuration

Each alert is a module that implements the `SQLert.Behaviour`:

- `query/0` - Returns the SQL query to execute
- `interval/0` - Sets how often to run (defaults to 5 minutes)
- `handle_result/1` - Processes the query result
- `handle_error/1` - Handles any errors (optional)
- `notifiers/0` - List of notification modules (optional)

## Telemetry Events

SQLert emits the following telemetry events:

- `[:sql_alert, :check, :complete]` - When an alert check completes
- `[:sql_alert, :query, :success]` - When a query succeeds
- `[:sql_alert, :query, :error]` - When a query fails
- `[:sql_alert, :handler, :error]` - When the result handler raises an error
- `[:sql_alert, :metrics, :update]` - When metrics are updated

## Custom Notifiers

Implement the `SQLert.Notifier` behaviour to create custom notification handlers:

```elixir
defmodule MyApp.Notifiers.Slack do
  @behaviour SQLert.Notifier

  @impl true
  def deliver(notification) do
    # Send to Slack
    message = format_message(notification)
    SlackAPI.post_message(message)
  end
end
```

## License

SQLert is released under the MIT License. See the LICENSE file for details.
