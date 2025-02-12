ExUnit.start()

# Start MockRepo for tests
{:ok, _} = SQLertTest.MockRepo.start_link([])

# Configure SQLert to use our mock DB
Application.put_env(:sqlert, :repo, SQLertTest.MockRepo)

defmodule TestHelpers do
  # Remove the notice message when an application is succesfully stopped
  #
  # > [notice] Application sqlert exited: :stopped
  def stop_sqlert_quietly do
    previous_level = Logger.level()
    Logger.configure(level: :warning)
    Application.stop(:sqlert)
    Logger.configure(level: previous_level)
  end
end
