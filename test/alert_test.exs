defmodule SQLertTest.AlertTest do
  use ExUnit.Case
  doctest SQLert

  describe "schedule configuration" do
    test "fails when missing" do
      assert_raise ArgumentError, ~r/schedule is required/, fn ->
        defmodule NoScheduleAlert do
          use SQLert.Alert, enabled: true

          def query, do: "SELECT 1"
          def handle_result(_), do: {:skip, %{}}
          def notifiers, do: []
        end
      end
    end

    test "fails when its an invalid cron expression" do
      assert_raise ArgumentError, ~r/invalid schedule/i, fn ->
        defmodule InvalidScheduleAlert do
          use SQLert.Alert, schedule: "not a cron", enabled: true

          def query, do: "SELECT 1"
          def handle_result(_), do: {:skip, %{}}
          def notifiers, do: []
        end
      end
    end

    test "compiles with valid expression" do
      defmodule ValidScheduleAlert do
        use SQLert.Alert, schedule: "*/5 * * * *", enabled: true

        def query, do: "SELECT 1"
        def handle_result(_), do: {:skip, %{}}
        def notifiers, do: []
      end

      # If we reach this point, it compiled successfully
      # We should clean up the module after the test
      :code.purge(ValidScheduleAlert)
      :code.delete(ValidScheduleAlert)
    end
  end

  describe "enabled configuration" do
    test "uses default value from SQLert config" do
      Application.put_env(:sqlert, :default_enabled, Mix.env() == :test)

      defmodule DefaultFromConfigAlert do
        use SQLert.Alert, schedule: "*/5 * * * *"

        def query, do: "SELECT 1"
        def handle_result(_), do: {:skip, %{}}
        def notifiers, do: []
      end

      # Since we're in :test env, it should be true
      assert DefaultFromConfigAlert.enabled?()

      # Cleanup
      :code.purge(DefaultFromConfigAlert)
      :code.delete(DefaultFromConfigAlert)
    end

    test "is resolved at runtime" do
      System.put_env("ALERT_ENABLED", "false")

      defmodule RuntimeEnabledAlert do
        use SQLert.Alert,
          schedule: "*/5 * * * *",
          enabled: System.get_env("ALERT_ENABLED", "true") == "true"

        def query, do: "SELECT 1"
        def handle_result(_), do: {:skip, %{}}
        def notifiers, do: []
      end

      refute RuntimeEnabledAlert.enabled?()

      # Change env and define a new module to verify
      System.put_env("ALERT_ENABLED", "true")

      defmodule RuntimeEnabledAlert2 do
        use SQLert.Alert,
          schedule: "*/5 * * * *",
          enabled: System.get_env("ALERT_ENABLED", "true") == "true"

        def query, do: "SELECT 1"
        def handle_result(_), do: {:skip, %{}}
        def notifiers, do: []
      end

      assert RuntimeEnabledAlert2.enabled?()

      # Cleanup
      System.delete_env("ALERT_ENABLED")
      :code.purge(RuntimeEnabledAlert)
      :code.purge(RuntimeEnabledAlert2)
      :code.delete(RuntimeEnabledAlert)
      :code.delete(RuntimeEnabledAlert2)
    end
  end

  describe "alert triggering" do
    setup do
      {:ok, _} = SQLertTest.MockNotifier.start_link()

      pid = Process.whereis(SQLertTest.EnabledAlert)

      {:ok, alert_pid: pid}
    end

    test "triggers alert when condition is met", %{alert_pid: pid} do
      # More than 10 users (see EnabledAlert)
      SQLertTest.MockRepo.set_result([[15]])
      SQLertTest.MockNotifier.clear()

      # Force execute the alert check
      GenServer.call(pid, :check_alert)

      [alert] = SQLertTest.MockNotifier.get_alerts()
      assert alert.message == "Too many users"
      assert alert.metadata.count > 10
    end

    test "skip alert notifications when condition is not met", %{alert_pid: pid} do
      # Less than 10 users (see EnabledAlert)
      SQLertTest.MockRepo.set_result([[6]])

      # Force execute the alert check
      GenServer.call(pid, :check_alert)

      assert SQLertTest.MockNotifier.get_alerts() == []
    end
  end

  describe "telemetry events" do
    setup do
      # Schedule for the next minute
      # schedule: "#{DateTime.utc_now().minute + 1} * * * *",
      # Track telemetry events
      test_pid = self()

      :telemetry.attach_many(
        "test-handler",
        [
          [:sqlert, :alert, :check],
          [:sqlert, :alert, :triggered],
          [:sqlert, :alert, :skipped]
        ],
        fn event_name, measurements, metadata, _ ->
          send(test_pid, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

      :ok
    end

    # test "emits telemetry events" do
    # {:ok, _pid} = DynamicSupervisor.start_child(SQLert.AlertSupervisor, TestAlert)
    #
    # Wait for check to happen
    # Process.sleep(100)
    #
    # Verify telemetry events
    # assert_receive {:telemetry_event, [:sqlert, :alert, :check], _measurements, %{alert: TestAlert}}
    # assert_receive {:telemetry_event, [:sqlert, :alert, :triggered], _measurements, %{alert: TestAlert}}
    # end
  end
end
