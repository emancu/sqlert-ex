defmodule SQLertTest do
  use ExUnit.Case
  doctest SQLert

  describe "discoverable_alerts/0" do
    test "automatic discover alerts that were compiled" do
      # Define a temporary Alert
      defmodule AnotherAlert do
        use SQLert.Alert,
          schedule: "* 1 * * *"

        def query, do: "SELECT COUNT(*) FROM users"
        def handle_result(_), do: {:skip, %{}}
        def notifiers, do: []
      end

      assert SQLert.discoverable_alerts() == [
               SQLertTest.AnotherAlert,
               SQLertTest.DisabledAlert,
               SQLertTest.EnabledAlert
             ]

      # Clean up
      :code.purge(SQLertTest.AnotherAlert)
      :code.delete(SQLertTest.AnotherAlert)
    end

    test "only alerts implementing the behaviour are detected" do
      # Define a temporary Alert
      defmodule NotAnAlert do
        def query, do: "SELECT COUNT(*) FROM users"

        def handle_result(_), do: {:skip, %{}}

        def notifiers, do: []
      end

      assert SQLert.discoverable_alerts() == [
               SQLertTest.DisabledAlert,
               SQLertTest.EnabledAlert
             ]

      # Clean up
      :code.purge(SQLertTest.NotAnAlert)
      :code.delete(SQLertTest.NotAnAlert)
    end
  end

  describe "running_alerts/0" do
    setup do
      # Make sure it is not running
      TestHelpers.stop_sqlert_quietly()

      on_exit(&TestHelpers.stop_sqlert_quietly/0)

      :ok
    end

    test "exits if the supervisor is not running" do
      assert {:noproc, _} = catch_exit(SQLert.running_alerts())
    end

    test "only return alerts, ignoring other processes supervised" do
      :ok = Application.start(:sqlert)
      # Define a temporary process to be supervised, to prove that
      # it is filtered out
      {:ok, pid} = supervise_a_non_alert_process()

      assert [SQLertTest.EnabledAlert] = SQLert.running_alerts()

      cleanup_non_alert_process(pid)
    end
  end

  ##
  # Helpers
  ##

  defp supervise_a_non_alert_process() do
    defmodule SomeProcessNotAlert do
      use GenServer

      def start_link(args) do
        GenServer.start_link(__MODULE__, args, name: __MODULE__)
      end

      def init(args) do
        {:ok, args}
      end
    end

    # Start supervising
    DynamicSupervisor.start_child(SQLert.AlertSupervisor, SomeProcessNotAlert)
  end

  defp cleanup_non_alert_process(pid) do
    DynamicSupervisor.terminate_child(SQLert.AlertSupervisor, pid)

    :code.purge(SQLertTest.SomeProcessNotAlert)
    :code.delete(SQLertTest.SomeProcessNotAlert)
  end
end
