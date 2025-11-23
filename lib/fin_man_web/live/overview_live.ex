defmodule FinManWeb.OverviewLive do
  use FinManWeb, :live_view

  require Logger

  alias FinMan.Ledger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, main_account} = Ledger.get_main_account()
    selected_date = Date.utc_today()

    socket
    |> assign(:main_account, main_account)
    |> assign(:selected_date, selected_date)
    |> load_monthly_data(selected_date)
    |> ok()
  end

  @impl true
  def handle_event("select_month", %{"month" => month_str}, socket) do
    case Date.from_iso8601(month_str <> "-01") do
      {:ok, selected_date} ->
        socket
        |> assign(:selected_date, selected_date)
        |> load_monthly_data(selected_date)
        |> noreply()

      {:error, error} ->
        Logger.error("Failed to select month: #{inspect(error)}")

        socket
        |> put_flash(:error, "Invalid month selected")
        |> noreply()
    end
  end

  @impl true
  def handle_event("select_month_year", %{"month" => month, "year" => year}, socket) do
    Logger.info("select_month_year event received with month: #{month}, year: #{year}")

    %{assigns: %{selected_date: current_date}} = socket

    month_num = String.to_integer(month)
    year_num = String.to_integer(year)

    # Ensure the selected day is valid for the new month/year
    day = min(current_date.day, days_in_month(year_num, month_num))

    case Date.new(year_num, month_num, day) do
      {:ok, selected_date} ->
        Logger.info("Selected date: #{inspect(selected_date)}")

        socket
        |> assign(:selected_date, selected_date)
        |> load_monthly_data(selected_date)
        |> noreply()

      {:error, error} ->
        Logger.error("Invalid date: #{inspect(error)}")

        socket
        |> put_flash(:error, "Invalid month/year selected")
        |> noreply()
    end
  end

  @impl true
  def handle_event("delete_transfer", %{"transfer_id" => transfer_id}, socket) do
    %{assigns: %{main_account: _main_account, selected_date: selected_date}} = socket

    case Ledger.destroy_transfer(transfer_id) do
      :ok ->
        socket
        |> load_monthly_data(selected_date)
        |> noreply()

      {:error, error} ->
        Logger.error("Failed to delete transfer: #{inspect(error)}")

        socket
        |> put_flash(:error, "Failed to delete transfer")
        |> noreply()
    end
  end

  defp load_monthly_data(socket, date) do
    %{assigns: %{main_account: main_account}} = socket

    summary = Ledger.calculate_monthly_summary(main_account.id, date)

    {:ok, spending_by_category} =
      Ledger.get_category_spending(
        Date.beginning_of_month(date),
        Date.end_of_month(date)
      )

    socket
    |> assign(:total_income, summary.total_income)
    |> assign(:total_expenses, summary.total_expenses)
    |> assign(:net_change, summary.net_change)
    |> assign(:incoming_transfers, summary.incoming_transfers)
    |> assign(:outgoing_transfers, summary.outgoing_transfers)
    |> assign(:spending_by_category, spending_by_category)
    |> assign(:current_month, Calendar.strftime(date, "%B %Y"))
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

      <%!-- Month and Year Selector --%>
      <.card variant="outline" padding="medium">
        <.card_content>
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold">Select Month and Year</h2>
            <.month_year_selector selected_date={@selected_date} />
          </div>
        </.card_content>
      </.card>

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
              <p class="text-sm text-gray-500 dark:text-gray-400 mb-1">Income for {@current_month}</p>
              <p class="text-2xl font-semibold text-success">
                {Money.to_string!(@total_income)}
              </p>
            </div>
          </.card_content>
        </.card>

        <.card variant="outline" color="danger" padding="medium">
          <.card_content>
            <div class="text-center">
              <p class="text-sm text-gray-500 dark:text-gray-400 mb-1">
                Expenses for {@current_month}
              </p>
              <p class="text-2xl font-semibold text-danger">
                {Money.to_string!(@total_expenses)}
              </p>
            </div>
          </.card_content>
        </.card>

        <.card variant="outline" color="info" padding="medium">
          <.card_content>
            <div class="text-center">
              <p class="text-sm text-gray-500 dark:text-gray-400 mb-1">
                Net Change for {@current_month}
              </p>
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
              No expenses for {@current_month}.
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
          <.card_title title={"Recent Income - #{@current_month}"} size="large" />
          <.card_content>
            <%= if @incoming_transfers == [] do %>
              <p class="text-gray-500 dark:text-gray-400 text-center py-4">
                No incoming transfers for {@current_month}.
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
          <.card_title title={"Recent Expenses - #{@current_month}"} size="large" />
          <.card_content>
            <%= if @outgoing_transfers == [] do %>
              <p class="text-gray-500 dark:text-gray-400 text-center py-4">
                No outgoing transfers for {@current_month}.
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

  defp month_year_selector(assigns) do
    ~H"""
    <div class="flex items-center gap-4">
      <button
        type="button"
        phx-click="select_month"
        phx-value-month={
          Date.add(@selected_date, -1)
          |> Date.beginning_of_month()
          |> Date.to_iso8601()
          |> String.slice(0, 7)
        }
        class="btn btn-ghost btn-sm"
        title="Previous month"
      >
        <.icon name="hero-chevron-left" class="w-4 h-4" />
      </button>

      <.form
        for={%{}}
        id="month-year-form"
        phx-change="select_month_year"
        class="flex items-center gap-2"
      >
        <select
          name="month"
          class="select select-bordered select-sm w-32"
        >
          <%= for {month_num, month_name} <- month_options() do %>
            <option
              value={month_num}
              selected={month_num == @selected_date.month}
            >
              {month_name}
            </option>
          <% end %>
        </select>

        <select
          name="year"
          class="select select-bordered select-sm w-24"
        >
          <%= for year <- year_options() do %>
            <option
              value={year}
              selected={year == @selected_date.year}
            >
              {year}
            </option>
          <% end %>
        </select>
      </.form>

      <button
        type="button"
        phx-click="select_month"
        phx-value-month={
          Date.add(@selected_date, 1)
          |> Date.beginning_of_month()
          |> Date.to_iso8601()
          |> String.slice(0, 7)
        }
        class="btn btn-ghost btn-sm"
        title="Next month"
      >
        <.icon name="hero-chevron-right" class="w-4 h-4" />
      </button>

      <button
        type="button"
        phx-click="select_month"
        phx-value-month={
          Date.utc_today() |> Date.beginning_of_month() |> Date.to_iso8601() |> String.slice(0, 7)
        }
        class="btn btn-primary btn-sm"
      >
        Today
      </button>
    </div>
    """
  end

  defp month_options do
    [
      {1, "January"},
      {2, "February"},
      {3, "March"},
      {4, "April"},
      {5, "May"},
      {6, "June"},
      {7, "July"},
      {8, "August"},
      {9, "September"},
      {10, "October"},
      {11, "November"},
      {12, "December"}
    ]
  end

  defp year_options do
    today = Date.utc_today()
    current_year = today.year
    start_year = current_year - 5

    Enum.to_list(start_year..current_year)
  end

  defp format_account_name(identifier) do
    case String.split(identifier, ":", parts: 2) do
      [_type, name] -> String.replace(name, "_", " ")
      [name] -> name
    end
  end

  defp days_in_month(year, month) do
    case Date.new(year, month, 1) do
      {:ok, date} -> Date.end_of_month(date).day
      # fallback
      {:error, _} -> 28
    end
  end
end
