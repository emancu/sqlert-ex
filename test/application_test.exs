defmodule SQLertTest.ApplicationTest do
  use ExUnit.Case
  doctest SQLert

  describe "application start" do
    test "immediatelly runs discoverable alerts that are enabled only" do
      TestHelpers.stop_sqlert_quietly()

      # Verify that alert are not running
      assert Process.whereis(SQLertTest.EnabledAlert) == nil
      assert Process.whereis(SQLertTest.DisabledAlert) == nil

      # Start the application which should discover and start alerts
      # Application.start(:sqlert)
      Application.ensure_all_started(:sqlert)

      assert [_only_one] = SQLert.running_alerts()
      assert Process.whereis(SQLertTest.EnabledAlert) != nil
      assert Process.whereis(SQLertTest.DisabledAlert) == nil
    end
  end

  describe "alert uniqueness" do
    test "prevents starting duplicate alerts" do
      Application.ensure_all_started(:sqlert)
      # Second start should fail since the alert is already running (boot)
      assert {:error, {:already_started, _}} =
               DynamicSupervisor.start_child(SQLert.AlertSupervisor, SQLertTest.EnabledAlert)
    end
  end
end
