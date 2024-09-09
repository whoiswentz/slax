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
alias Slax.Chat.Message
alias Slax.Accounts.User
alias Slax.Accounts
alias Slax.Chat

{:ok, frodo} = Accounts.register_user(%{email: "frodo@lotr.com", password: "password123456"})
{:ok, bildo} = Accounts.register_user(%{email: "bildo@lotr.com", password: "password123456"})

{:ok, the_shire} = Chat.create_room(%{name: "the-shire", topic: "Bilbo's birthday party"})
{:ok, mordor} = Chat.create_room(%{name: "mordor", topic: "The Dark Lord has returned"})

Repo.insert!(%Message{
  room_id: the_shire.id,
  user_id: bildo.id,
  body: "Do not take me for a conjurer of cheap tricks!"
})
