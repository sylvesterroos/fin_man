defmodule FinMan.Ledger.Transfer do
  use Ash.Resource,
    domain: FinMan.Ledger,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshDoubleEntry.Transfer]

  alias FinMan.Ledger

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
      accept [
        :amount,
        :timestamp,
        :from_account_id,
        :to_account_id,
        :description,
        :date
      ]
    end

    read :get_transfers do
      require Ash.Query
      alias Ash.Query

      argument :account_id, :uuid, allow_nil?: false

      argument :type, :atom do
        constraints one_of: [:income, :expense]
        allow_nil? false
      end

      argument :limit, :integer, default: 10
      argument :date, :date

      prepare build(
                load: [:from_account, :to_account],
                sort: [date: :desc, inserted_at: :desc]
              )

      prepare fn query, _context ->
        target_date = Query.get_argument(query, :date) || Date.utc_today()
        limit = Query.get_argument(query, :limit)
        account_id = Query.get_argument(query, :account_id)
        type = Query.get_argument(query, :type)

        first_of_month = Date.beginning_of_month(target_date)
        last_of_month = Date.end_of_month(target_date)

        query
        |> Query.limit(limit)
        |> Query.filter(expr(date >= ^first_of_month and date <= ^last_of_month))
        |> then(fn query ->
          case type do
            nil -> query
            :income -> Query.filter(query, expr(to_account_id == ^account_id))
            :expense -> Query.filter(query, expr(from_account_id == ^account_id))
          end
        end)
      end
    end

    create :create_income do
      accept [:amount, :from_account_id, :description, :date]

      change fn changeset, _context ->
        changeset |> dbg()

        case Ledger.get_main_account() do
          {:ok, main_account} ->
            Ash.Changeset.change_attribute(changeset, :to_account_id, main_account.id)

          {:error, error} ->
            Ash.Changeset.add_error(changeset, error)
        end
      end
    end

    create :create_expense do
      accept [:amount, :to_account_id, :description, :date]

      change fn changeset, _context ->
        case Ledger.get_main_account() do
          {:ok, main_account} ->
            Ash.Changeset.change_attribute(changeset, :from_account_id, main_account.id)

          {:error, error} ->
            Ash.Changeset.add_error(changeset, error)
        end
      end
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
      # TODO: add the default_currency value to config.exs
      constraints ex_money_opts: [default_currency: :EUR]
    end

    attribute :description, :string do
      allow_nil? true
    end

    attribute :date, :date do
      allow_nil? false
      default &Date.utc_today/0
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
