defmodule SQLertTest.QueryTypesTest do
  @moduledoc """
  Tests different types of queries that SQLert can handle.

  These tests use SQLertTest.MockRepo to simulate database responses
  and verify both raw SQL and Ecto query support.
  """
  use ExUnit.Case

  describe "query types" do
    setup do
      {:ok, _} = SQLertTest.MockNotifier.start_link()
      # {:ok, _} = SQLertTest.MockRepo.start_link([])
      :ok
    end

    test "executes raw SQL queries" do
      defmodule RawSQLAlert do
        use SQLert.Alert,
          schedule: "*/5 * * * *",
          enabled: false

        def query, do: "SELECT count(*) FROM users"
        def handle_result([[count]]), do: {:alert, "Count: #{count}", %{count: count}}
        def notifiers, do: [SQLertTest.MockNotifier]
      end

      SQLertTest.MockRepo.set_result([[42]])
      # Forcing function execution, for better control
      {:noreply, state} = RawSQLAlert.handle_info(:check_alert, %{last_run: nil})

      [alert] = SQLertTest.MockNotifier.get_alerts()
      assert alert.metadata.count == 42
      refute nil == state.last_run

      :code.purge(RawSQLAlert)
      :code.delete(RawSQLAlert)
    end

    test "executes Ecto queries" do
      defmodule EctoQueryAlert do
        use SQLert.Alert,
          schedule: "*/5 * * * *",
          enabled: false

        def query do
          import Ecto.Query
          from(u in "users", select: count(u.id))
        end

        def handle_result([count]), do: {:alert, "Count: #{count}", %{count: count}}

        def notifiers, do: [SQLertTest.MockNotifier]
      end

      SQLertTest.MockRepo.set_result([[55]])
      # Forcing function execution, for better control
      {:noreply, state} = EctoQueryAlert.handle_info(:check_alert, %{last_run: nil})

      [alert] = SQLertTest.MockNotifier.get_alerts()
      assert alert.metadata.count == 55
      refute nil == state.last_run

      :code.purge(EctoQueryAlert)
      :code.delete(EctoQueryAlert)
    end
  end
end
