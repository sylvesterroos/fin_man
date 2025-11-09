defmodule FinMan.Ledger do
  use Ash.Domain,
    otp_app: :fin_man,
    extensions: [AshPhoenix.Domain]

  resources do
    resource FinMan.Ledger.Account do
      define :open, action: :open
      define :read_accounts, action: :read
      define :lock_accounts, action: :lock_accounts
      define :get_account, action: :by_id, args: [:id], get?: true
      define :get_account_by_identifier, action: :by_identifier, args: [:identifier], get?: true
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
    end
  end
end
