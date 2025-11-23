defmodule FinManWeb.OverviewLive do
  use FinManWeb, :live_view

  require Logger

  alias FinMan.Ledger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, main_account} = Ledger.get_main_account()

    summary = Ledger.calculate_monthly_summary(main_account.id, Date.utc_today())

    # Ledger.calculate_spending_by_category(main_account.id, Date.utc_today())
    {:ok, spending_by_category} =
      Ledger.get_category_spending(
        Date.beginning_of_month(Date.utc_today()),
        Date.end_of_month(Date.utc_today())
      )

    {:ok,
     socket
     |> assign(:main_account, main_account)
     |> assign(:total_income, summary.total_income)
     |> assign(:total_expenses, summary.total_expenses)
     |> assign(:net_change, summary.net_change)
     |> assign(:incoming_transfers, summary.incoming_transfers)
     |> assign(:outgoing_transfers, summary.outgoing_transfers)
     |> assign(:spending_by_category, spending_by_category)
     |> assign(:current_month, Calendar.strftime(Date.utc_today(), "%B %Y"))}
  end

  @impl true
  def handle_event("delete_transfer", %{"transfer_id" => transfer_id}, socket) do
    case Ledger.destroy_transfer(transfer_id) do
      :ok ->
        %{assigns: %{main_account: main_account}} = socket

        summary = Ledger.calculate_monthly_summary(main_account.id, Date.utc_today())

        socket
        |> assign(
          main_account: main_account,
          total_income: summary.total_income,
          total_expenses: summary.total_expenses,
          net_change: summary.net_change,
          incoming_transfers: summary.incoming_transfers,
          outgoing_transfers: summary.outgoing_transfers
        )
        |> noreply()

      {:error, error} ->
        Logger.error("Failed to delete transfer: #{inspect(error)}")

        socket
        |> put_flash(:error, "Failed to delete transfer")
        |> noreply()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header --%>
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold">Financial Overview</h1>
        <.link navigate="/transfers/new" class="btn btn-primary">
          New Transfer
        </.link>
      </div>

      <%!-- Main Account Balance Card --%>
      <.card variant="outline" color="primary" padding="large">
        <.card_content>
          <div class="text-center">
            <p class="text-sm text-gray-500 dark:text-gray-400 mb-2">Main Account Balance</p>
            <p class="text-4xl font-bold text-primary">
              {Money.to_string!(@main_account.balance_as_of)}
            </p>
          </div>
        </.card_content>
      </.card>

      <%!-- Monthly Summary --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <.card variant="outline" color="success" padding="medium">
          <.card_content>
            <div class="text-center">
              <p class="text-sm text-gray-500 dark:text-gray-400 mb-1">Income This Month</p>
              <p class="text-2xl font-semibold text-success">
                {Money.to_string!(@total_income)}
              </p>
            </div>
          </.card_content>
        </.card>

        <.card variant="outline" color="danger" padding="medium">
          <.card_content>
            <div class="text-center">
              <p class="text-sm text-gray-500 dark:text-gray-400 mb-1">Expenses This Month</p>
              <p class="text-2xl font-semibold text-danger">
                {Money.to_string!(@total_expenses)}
              </p>
            </div>
          </.card_content>
        </.card>

        <.card variant="outline" color="info" padding="medium">
          <.card_content>
            <div class="text-center">
              <p class="text-sm text-gray-500 dark:text-gray-400 mb-1">Net Change</p>
              <p class="text-2xl font-semibold text-info">
                {Money.to_string!(@net_change)}
              </p>
            </div>
          </.card_content>
        </.card>
      </div>

      <%!-- Spending by Category --%>
      <.card variant="outline" padding="large">
        <.card_title title={"Spending by Category - #{@current_month}"} size="large" />
        <.card_content>
          <%= if @spending_by_category == [] do %>
            <p class="text-gray-500 dark:text-gray-400 text-center py-4">
              No expenses this month yet.
            </p>
          <% else %>
            <div class="space-y-3">
              <%= for %FinMan.Ledger.Account{category_name: category, spent_between: amount} <- @spending_by_category do %>
                <div class="flex justify-between items-center">
                  <span class="font-medium">{category}</span>
                  <span class="text-danger font-semibold">{Money.to_string!(amount)}</span>
                </div>
              <% end %>
            </div>
          <% end %>
        </.card_content>
      </.card>

      <%!-- Recent Transfers --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Incoming Transfers --%>
        <.card variant="outline" padding="large">
          <.card_title title="Recent Income" size="large" />
          <.card_content>
            <%= if @incoming_transfers == [] do %>
              <p class="text-gray-500 dark:text-gray-400 text-center py-4">
                No incoming transfers this month.
              </p>
            <% else %>
              <div class="space-y-3">
                <%= for transfer <- @incoming_transfers do %>
                  <div class="border-b border-gray-200 dark:border-gray-700 pb-3 last:border-b-0">
                    <div class="flex justify-between items-start">
                      <div class="flex-1">
                        <p class="font-medium text-sm">{transfer.description}</p>
                        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                          From: {format_account_name(transfer.from_account.identifier)}
                        </p>
                        <p class="text-xs text-gray-500 dark:text-gray-400">
                          {Calendar.strftime(transfer.date, "%b %d, %Y")}
                        </p>
                      </div>
                      <div class="flex items-center gap-2">
                        <span class="text-success font-semibold">
                          +{Money.to_string!(transfer.amount)}
                        </span>
                        <button
                          type="button"
                          phx-click="delete_transfer"
                          phx-value-transfer_id={transfer.id}
                          class="text-red-500 hover:text-red-700 transition-colors"
                          title="Delete transfer"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </.card_content>
        </.card>

        <%!-- Outgoing Transfers --%>
        <.card variant="outline" padding="large">
          <.card_title title="Recent Expenses" size="large" />
          <.card_content>
            <%= if @outgoing_transfers == [] do %>
              <p class="text-gray-500 dark:text-gray-400 text-center py-4">
                No outgoing transfers this month.
              </p>
            <% else %>
              <div class="space-y-3">
                <%= for transfer <- @outgoing_transfers do %>
                  <div class="border-b border-gray-200 dark:border-gray-700 pb-3 last:border-b-0">
                    <div class="flex justify-between items-start">
                      <div class="flex-1">
                        <p class="font-medium text-sm">{transfer.description}</p>
                        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                          To: {format_account_name(transfer.to_account.identifier)}
                        </p>
                        <p class="text-xs text-gray-500 dark:text-gray-400">
                          {Calendar.strftime(transfer.date, "%b %d, %Y")}
                        </p>
                      </div>
                      <div class="flex items-center gap-2">
                        <span class="text-danger font-semibold">
                          -{Money.to_string!(transfer.amount)}
                        </span>
                        <button
                          type="button"
                          phx-click="delete_transfer"
                          phx-value-transfer_id={transfer.id}
                          class="text-red-500 hover:text-red-700 transition-colors"
                          title="Delete transfer"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </.card_content>
        </.card>
      </div>
    </div>
    """
  end

  defp format_account_name(identifier) do
    case String.split(identifier, ":", parts: 2) do
      [_type, name] -> String.replace(name, "_", " ")
      [name] -> name
    end
  end
end
