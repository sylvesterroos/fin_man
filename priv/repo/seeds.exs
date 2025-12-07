# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FinMan.Repo.insert!(%FinMan.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Seed accounts idempotently
FinMan.Seeds.seed_accounts()

with {:ok, salary_acc} <- FinMan.Ledger.get_account_by_identifier("Income:Salary") do
  FinMan.Ledger.create_income_transfer!(%{
    from_account_id: salary_acc.id,
    amount: "2650"
  })
end

expense_seeds = [
  {"Groceries",
   [
     %{amount: "44"},
     %{amount: "30"},
     %{amount: "39"},
     %{amount: "12"},
     %{amount: "9"}
   ]},
  {"Rent",
   [
     %{amount: "1050", description: "Inclusief energievoorschot"}
   ]},
  {"Gasoline",
   [
     %{amount: "55", description: "Auto"},
     %{amount: "29", description: "Motor"}
   ]},
  {"Insurance",
   [
     %{amount: "150"}
   ]},
  {"Dining out/Take-away",
   [
     %{amount: "10.5", description: "Pizza"},
     %{amount: "45", description: "Uit eten in Oude Haven"}
   ]},
  {"Shopping",
   [
     %{amount: "145", description: "Nieuwe sweater"},
     %{amount: "155", description: "Nieuwe hoodie"}
   ]},
  {"Subscriptions",
   [
     %{amount: "2.5", description: "VPN"},
     %{amount: "5", description: "Amazon Prime"}
   ]}
]

for {category_name, params} <- expense_seeds do
  account_identifier = "Expenses:#{category_name}"

  with {:ok, account} <- FinMan.Ledger.get_account_by_identifier(account_identifier) do
    Enum.each(
      params,
      &FinMan.Ledger.create_expense_transfer!(Map.merge(&1, %{to_account_id: account.id}))
    )
  end
end
