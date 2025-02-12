defmodule SQLert.Alert do
  @moduledoc """
  Defines an SQL-based alert (Behaviour).

  SQLert alerts are modules that specify SQL queries to be executed on schedule,
  checking for specific conditions in your database. When these conditions are met,
  alerts can trigger notifications through various channels.

  ## Alert Lifecycle

  Each alert runs in its own process and follows this lifecycle:

    1. At the configured schedule, the alert's `query/0` callback is executed
    2. The query result is passed to `handle_result/1`
    3. If `handle_result/1` returns `{:alert, message, metadata}`, notifications are sent
    4. The process waits for the next scheduled

  ## Defining Alerts

  To define an alert, create a module that uses `SQLert.Alert` and implement
  the required callbacks:

      defmodule MyApp.Alerts.HighErrorRate do
        use SQLert.Alert,
          schedule: "10 * * * *"
          enabled: true

        @impl true
        def query do
          "SELECT COUNT(*) FROM errors WHERE created_at > NOW() - INTERVAL '1 hour'"
        end

        @impl true
        def handle_result([[count]]}) when count > 100 do
          {:alert, "High error rate detected", %{count: count}}
        end
        def handle_result(_) do
          {:skip, %{count: 0}}
        end

        @impl true
        def notifiers do
          [MyApp.Alerts.Notifiers.Slack]
        end
      end

  ## Configuration Options

    * `:schedule` - (String) Cron notation with the alert schedule. *REQUIRED*
    * `:enabled`  - (Boolean) Whether this alert should run. Defaults to `Mix.env() == :prod`

  ## Query Types

  The `query/0` callback can return either a string SQL query or an Ecto query:

      # Raw SQL
      def query do
        "SELECT COUNT(*) FROM users WHERE last_login < NOW() - INTERVAL '30 days'"
      end

      # Ecto query
      def query do
        from u in User,
          where: u.last_login < ago(30, "day"),
          select: count(u.id)
      end

  ## Handling Results

  The `handle_result/1` callback receives the query result and must return one of:

    * `{:alert, message, metadata}` - Trigger notifications with the given message
    * `{:skip, metadata}` - Condition not met, skip notifications

  For SQL queries, results come in the format `%{rows: [[value]]}`. For Ecto queries,
  you receive the direct query result.


  ## Notifications

  Alerts can have multiple notifiers that implement the `SQLert.Notifier` behaviour.
  Define them in the `notifiers/0` callback:

      def notifiers do
        [
          MyApp.Alerts.Notifiers.Slack,
          MyApp.Alerts.Notifiers.Email
        ]
      end

  See `SQLert.Notifier` for details on implementing notifiers.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          metadata: map()
        }

  defstruct [:message, :metadata]

  @type query :: String.t() | Ecto.Query.t()
  @type alert_result :: {:alert, String.t(), map()} | {:skip, map()}

  @callback query() :: query()
  @callback handle_result(any()) :: alert_result()
  @callback notifiers() :: [module()]

  defmacro __using__(opts) do
    with {:ok, schedule} <- Keyword.fetch(opts, :schedule),
         {:ok, _} <- Crontab.CronExpression.Parser.parse(schedule) do
      :ok
    else
      :error ->
        raise ArgumentError, "schedule is required for SQLert alerts"

      {:error, parse_error} ->
        raise ArgumentError, "invalid schedule: #{parse_error}"
    end

    quote do
      use GenServer
      @behaviour SQLert.Alert

      Module.register_attribute(__MODULE__, :sqlert, persist: true)
      @sqlert true

      Module.register_attribute(__MODULE__, :sqlert_schedule, persist: true)
      @sqlert_schedule unquote(opts[:schedule])

      def enabled? do
        Keyword.get(
          unquote(opts),
          :enabled,
          Application.get_env(:sqlert, :default_enabled, true)
        )
      end

      ###
      # GenServer related functions
      ###
      def start_link(_) do
        GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
      end

      @impl GenServer
      def init(_) do
        schedule_next_run()

        {:ok, %{last_run: nil}}
      end

      @impl GenServer
      def handle_call(:check_alert, _from, state) do
        new_state = check(state)

        {:reply, :ok, new_state}
      end

      @impl GenServer
      def handle_info(:check_alert, state) do
        new_state = check(state)

        {:noreply, new_state}
      end

      defp check(state) do
        query()
        |> execute_query()
        |> handle_result()
        |> notify()

        schedule_next_run()

        %{state | last_run: DateTime.utc_now()}
      end

      defp execute_query(%Ecto.Query{} = query), do: repo().all(query)

      defp execute_query(query) when is_binary(query) do
        %{rows: rows} = repo().query!(query)

        rows
      end

      defp notify({:alert, message, metadata}) do
        notifiers()
        |> Enum.each(fn notifier ->
          %SQLert.Alert{message: message, metadata: metadata}
          |> notifier.deliver()
        end)
      end

      defp notify({:skip, metadata}), do: :ok

      defp schedule_next_run do
        import Logger
        Logger.info("Scheduling next run: #{__MODULE__}")
        now = DateTime.utc_now() |> DateTime.to_naive()
        cron = Crontab.CronExpression.Parser.parse!(@sqlert_schedule)
        next_run = Crontab.Scheduler.get_next_run_date!(cron, now)
        delay = NaiveDateTime.diff(next_run, now, :millisecond)

        Process.send_after(self(), :check_alert, max(0, delay))
      end

      defp repo, do: Application.fetch_env!(:sqlert, :repo)
    end
  end
end
