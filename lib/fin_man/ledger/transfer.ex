defmodule FinMan.Ledger.Transfer do
  use Ash.Resource,
    domain: Elixir.FinMan.Ledger,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Transfer]

  transfer do
    account_resource FinMan.Ledger.Account
    balance_resource FinMan.Ledger.Balance
  end

  postgres do
    table "ledger_transfers"
    repo FinMan.Repo
  end

  actions do
    defaults [:read]

    create :transfer do
      accept [:amount, :timestamp, :from_account_id, :to_account_id]
    end
  end

  attributes do
    attribute :id, AshDoubleEntry.ULID do
      primary_key? true
      allow_nil? false
      default &AshDoubleEntry.ULID.generate/0
    end

    attribute :amount, :money do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :from_account, FinMan.Ledger.Account do
      attribute_writable? true
    end

    belongs_to :to_account, FinMan.Ledger.Account do
      attribute_writable? true
    end

    has_many :balances, FinMan.Ledger.Balance
  end
end
