defmodule FinMan.Seeds do
  @moduledoc """
  Idempotent seed functions for accounts.
  """

  require Logger

  @doc """
  Creates an account if it doesn't already exist.
  Returns {:ok, account} if created or already exists, or {:error, reason} if creation fails.
  """
  def create_account_if_not_exists(identifier, currency \\ "EUR") do
    case FinMan.Ledger.get_account_by_identifier(identifier) do
      {:ok, account} ->
        Logger.info("Account already exists: #{identifier}")
        {:ok, account}

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Check if this is a "not found" error
        case Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) do
          true ->
            Logger.info("Creating account: #{identifier}")

            FinMan.Ledger.open(%{
              identifier: identifier,
              currency: currency
            })

          false ->
            Logger.error("Failed to check account existence: #{inspect(errors)}")
            {:error, %Ash.Error.Invalid{errors: errors}}
        end

      {:error, reason} ->
        Logger.error("Failed to check account existence: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Creates an account if it doesn't already exist (bang version).
  Returns the account if created or already exists, raises on error.
  """
  def create_account_if_not_exists!(identifier, currency \\ "EUR") do
    case create_account_if_not_exists(identifier, currency) do
      {:ok, account} -> account
      {:error, error} -> raise error
    end
  end

  @doc """
  Seeds all accounts (main, income, and expense accounts).
  This function is idempotent and can be run multiple times safely.
  """
  def seed_accounts do
    # Create main account
    create_account_if_not_exists!("Assets:Account")

    income_categories = [
      "Salary",
      "Investment",
      "Other Income"
    ]

    for category_name <- income_categories do
      account_identifier = "Income:#{category_name}"
      create_account_if_not_exists!(account_identifier)
    end

    expense_categories = [
      "Groceries",
      "Rent",
      "Utilities",
      "Gasoline",
      "Vehicle maintenance",
      "Entertainment",
      "Healthcare",
      "Insurance",
      "Dining out/Take-away",
      "Shopping",
      "Subscriptions",
      "Other Expenses"
    ]

    for category_name <- expense_categories do
      account_identifier = "Expenses:#{category_name}"
      create_account_if_not_exists!(account_identifier)
    end
  end
end
