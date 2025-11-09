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

# Create the main account
case FinMan.Ledger.get_account_by_identifier("Assets:Account") do
  {:ok, _account} ->
    IO.puts("Main account already exists")

  {:error, _error} ->
    {:ok, _account} =
      FinMan.Ledger.open(%{
        identifier: "Assets:Account",
        currency: "EUR"
      })

    IO.puts("Created main account")
end

# Create common income accounts
income_categories = [
  "Salary",
  "Investment",
  "Other_Income"
]

for category_name <- income_categories do
  account_identifier = "Income:#{category_name}"

  case FinMan.Ledger.get_account_by_identifier(account_identifier) do
    {:ok, _account} ->
      IO.puts("Income account already exists: #{account_identifier}")

    {:error, _error} ->
      {:ok, _account} =
        FinMan.Ledger.open(%{
          identifier: account_identifier,
          currency: "EUR"
        })

      IO.puts("Created income account: #{account_identifier}")
  end
end

# Create common expense accounts
expense_categories = [
  "Groceries",
  "Rent",
  "Utilities",
  "Gasoline",
  "Vehicle_maintenance",
  "Entertainment",
  "Healthcare",
  "Insurance",
  "Dining_Out",
  "Shopping",
  "Subscriptions",
  "Other_Expenses"
]

for category_name <- expense_categories do
  account_identifier = "Expenses:#{category_name}"

  case FinMan.Ledger.get_account_by_identifier(account_identifier) do
    {:ok, _account} ->
      IO.puts("Expense account already exists: #{account_identifier}")

    {:error, _error} ->
      {:ok, _account} =
        FinMan.Ledger.open(%{
          identifier: account_identifier,
          currency: "EUR"
        })

      IO.puts("Created expense account: #{account_identifier}")
  end
end

IO.puts("\nDatabase seeded successfully!")
