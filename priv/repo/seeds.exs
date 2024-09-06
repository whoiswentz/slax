# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Slax.Repo.insert!(%Slax.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Slax.Repo
alias Slax.Chat.Room

Repo.insert!(%Room{name: "the-shire", topic: "Bilbo's birthday party"})
Repo.insert!(%Room{name: "mordor", topic: "The Dark Lord has returned"})
