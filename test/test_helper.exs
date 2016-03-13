ExUnit.start

Mix.Task.run "ecto.create", ~w(-r Paladin.Repo --quiet)
Mix.Task.run "ecto.migrate", ~w(-r Paladin.Repo --quiet)
Ecto.Adapters.SQL.begin_test_transaction(Paladin.Repo)

