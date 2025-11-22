defmodule FinMan.Ledger do
  use Ash.Domain,
    otp_app: :fin_man,
    extensions: [AshPhoenix.Domain]

  require Ash.Query
  require Logger

  alias FinMan.Ledger.Transfer

  resources do
    resource FinMan.Ledger.Account do
      define :open, action: :open
      define :read_accounts, action: :read
      define :lock_accounts, action: :lock_accounts
      define :get_account, action: :by_id, args: [:id], get?: true
      define :get_account_by_identifier, action: :by_identifier, args: [:identifier], get?: true
      define :get_income_accounts, action: :get_income_accounts
      define :get_expense_accounts, action: :get_expense_accounts

      define :get_category_spending,
        action: :get_category_spending,
        args: [:start_date, :end_date]
    end

    resource FinMan.Ledger.Balance do
      define :read_balances, action: :read
      define :upsert_balance, action: :upsert_balance
      define :adjust_balance, action: :adjust_balance
    end

    resource FinMan.Ledger.Transfer do
      define :transfer, action: :transfer
      define :read_transfers, action: :read
      define :create_transfer, action: :transfer
      define :get_transfers, action: :get_transfers
      define :create_income_transfer, action: :create_income
      define :create_expense_transfer, action: :create_expense
    end
  end

  def get_main_account do
    with {:ok, account} <- get_account_by_identifier("Assets:Account"),
         {:ok, account_with_balance} <-
           Ash.load(account, balance_as_of: %{timestamp: DateTime.utc_now()}) do
      {:ok, account_with_balance}
    else
      {:error, error} ->
        Logger.error("Failed to get the main account: #{inspect(error)}")
        {:error, error}
    end
  end

  def get_main_account! do
    case get_main_account() do
      {:ok, account} -> account
      {:error, error} -> raise error
    end
  end

  def get_incoming_transfers(account_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    date = Keyword.get(opts, :date, Date.utc_today())

    first_of_month = Date.beginning_of_month(date)
    last_of_month = Date.end_of_month(date)

    query =
      Transfer
      |> Ash.Query.filter(
        to_account_id == ^account_id and date >= ^first_of_month and date <= ^last_of_month
      )
      |> Ash.Query.sort(date: :desc, inserted_at: :desc)
      |> Ash.Query.limit(limit)
      |> Ash.Query.load([:from_account, :to_account])

    Ash.read(query)
  end

  def get_outgoing_transfers(account_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    date = Keyword.get(opts, :date, Date.utc_today())

    first_of_month = Date.beginning_of_month(date)
    last_of_month = Date.end_of_month(date)

    query =
      Transfer
      |> Ash.Query.filter(
        from_account_id == ^account_id and date >= ^first_of_month and date <= ^last_of_month
      )
      |> Ash.Query.sort(date: :desc, inserted_at: :desc)
      |> Ash.Query.limit(limit)
      |> Ash.Query.load([:from_account, :to_account])

    Ash.read(query)
  end

  def calculate_monthly_summary(account_id, date \\ Date.utc_today()) do
    {:ok, incoming_transfers} =
      get_transfers(%{account_id: account_id, type: :income, limit: 25, date: date})

    {:ok, outgoing_transfers} =
      get_transfers(%{account_id: account_id, type: :expense, limit: 25, date: date})

    total_income =
      incoming_transfers
      |> Enum.reduce(Money.new(0, :EUR), fn t, acc ->
        Money.add!(acc, t.amount)
      end)

    total_expenses =
      outgoing_transfers
      |> Enum.reduce(Money.new(0, :EUR), fn t, acc ->
        Money.add!(acc, t.amount)
      end)

    net_change = Money.sub!(total_income, total_expenses)

    %{
      total_income: total_income,
      total_expenses: total_expenses,
      net_change: net_change,
      incoming_transfers: Enum.take(incoming_transfers, 10),
      outgoing_transfers: Enum.take(outgoing_transfers, 10)
    }
  end
end
