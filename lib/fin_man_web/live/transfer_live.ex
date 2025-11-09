defmodule FinManWeb.TransferLive do
  use FinManWeb, :live_view

  alias FinMan.Ledger
  alias FinMan.Ledger.Transfer

  @impl true
  def mount(_params, _session, socket) do
    accounts = Ledger.read_accounts!() |> Ash.load!([:account_type, :category_name])
    transfers = load_transfers()

    socket =
      socket
      |> assign(:accounts, accounts)
      |> assign(:transfer_type, :incoming)
      |> assign_new_form()
      |> assign(:transfers, transfers)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-gray-900">Transfers</h1>
      </div>

      <.card color="white" rounded="large" padding="large">
        <.card_title title="New Transfer" size="large" />

        <.card_content>
          <div class="mb-6">
            <div class="inline-flex rounded-lg border border-gray-200 p-1 bg-gray-50">
              <button
                type="button"
                phx-click="switch-type"
                phx-value-type="incoming"
                class={[
                  "px-4 py-2 text-sm font-medium rounded-md transition-colors",
                  @transfer_type == :incoming &&
                    "bg-white text-blue-600 shadow-sm",
                  @transfer_type != :incoming && "text-gray-600 hover:text-gray-900"
                ]}
              >
                Incoming
              </button>
              <button
                type="button"
                phx-click="switch-type"
                phx-value-type="outgoing"
                class={[
                  "px-4 py-2 text-sm font-medium rounded-md transition-colors",
                  @transfer_type == :outgoing &&
                    "bg-white text-blue-600 shadow-sm",
                  @transfer_type != :outgoing && "text-gray-600 hover:text-gray-900"
                ]}
              >
                Outgoing
              </button>
            </div>
          </div>

          <.form for={@form} id="transfer-form" phx-change="validate" phx-submit="submit">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= if @transfer_type == :incoming do %>
                <.input
                  type="select"
                  field={@form[:from_account_id]}
                  label="From Account (Income)"
                  options={income_account_options(@accounts)}
                  prompt="Select source account"
                />
                <.input
                  type="select"
                  field={@form[:to_account_id]}
                  label="To Account (Assets)"
                  options={asset_account_options(@accounts)}
                  prompt="Select destination account"
                />
              <% else %>
                <.input
                  type="select"
                  field={@form[:from_account_id]}
                  label="From Account (Assets)"
                  options={asset_account_options(@accounts)}
                  prompt="Select source account"
                />
                <.input
                  type="select"
                  field={@form[:to_account_id]}
                  label="To Account (Expenses)"
                  options={expense_account_options(@accounts)}
                  prompt="Select destination account"
                />
              <% end %>

              <.input
                name={@form[:amount].name <> "[amount]"}
                id={@form[:amount].id <> "_amount"}
                label="Amount"
                type="number"
                step="0.01"
                value={if(@form[:amount].value, do: @form[:amount].value.amount)}
              />

              <.input
                type="select"
                name={@form[:amount].name <> "[currency]"}
                id={@form[:amount].id <> "_currency"}
                options={["EUR", "USD", "GBP", "HKD"]}
                label="Currency"
                value={if(@form[:amount].value, do: @form[:amount].value.currency)}
              />

              <.input type="date" field={@form[:date]} label="Date" />
            </div>

            <.input
              type="textarea"
              field={@form[:description]}
              label="Description"
              placeholder="Optional description"
              class="mt-4"
            />

            <div class="flex justify-end mt-6">
              <.button type="submit" color="primary" variant="default" size="medium">
                Create Transfer
              </.button>
            </div>
          </.form>
        </.card_content>
      </.card>

      <.card color="white" rounded="large" padding="large">
        <.card_title title="Recent Transfers" size="large" />

        <.card_content>
          <.table variant="default" color="natural" padding="medium" rounded="small">
            <:header>Date</:header>
            <:header>From</:header>
            <:header>To</:header>
            <:header>Amount</:header>
            <:header>Description</:header>

            <%= for transfer <- @transfers do %>
              <.tr>
                <.td>{transfer.date}</.td>
                <.td>{get_account_display(transfer.from_account)}</.td>
                <.td>{get_account_display(transfer.to_account)}</.td>
                <.td>{format_money(transfer.amount)}</.td>
                <.td>{transfer.description}</.td>
              </.tr>
            <% end %>
          </.table>
        </.card_content>
      </.card>
    </div>
    """
  end

  @impl true
  def handle_event("switch-type", %{"type" => type}, socket) do
    transfer_type = String.to_existing_atom(type)

    socket =
      socket
      |> assign(:transfer_type, transfer_type)
      |> assign_new_form()

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("submit", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, _transfer} ->
        socket =
          socket
          |> put_flash(:info, "Transfer created successfully")
          |> assign_new_form()
          |> assign(:transfers, load_transfers())

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp load_transfers do
    Ledger.read_transfers!(load: [:from_account, :to_account])
    |> Enum.map(fn transfer ->
      transfer
      |> Map.update!(:from_account, &maybe_load_calculations/1)
      |> Map.update!(:to_account, &maybe_load_calculations/1)
    end)
  end

  defp maybe_load_calculations(nil), do: nil

  defp maybe_load_calculations(account) do
    Ash.load!(account, [:account_type, :category_name])
  end

  defp assign_new_form(socket) do
    form =
      Transfer
      |> AshPhoenix.Form.for_create(:transfer,
        domain: Ledger,
        as: "form",
        params: %{"date" => Date.utc_today()}
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp asset_account_options(accounts) do
    accounts
    |> Enum.filter(fn account -> account.account_type == "Assets" end)
    |> Enum.map(fn account ->
      {"Assets: #{format_category_name(account.category_name)}", account.id}
    end)
  end

  defp income_account_options(accounts) do
    accounts
    |> Enum.filter(fn account -> account.account_type == "Income" end)
    |> Enum.map(fn account ->
      {"Income: #{format_category_name(account.category_name)}", account.id}
    end)
  end

  defp expense_account_options(accounts) do
    accounts
    |> Enum.filter(fn account -> account.account_type == "Expenses" end)
    |> Enum.map(fn account ->
      {"Expenses: #{format_category_name(account.category_name)}", account.id}
    end)
  end

  defp get_account_display(account) do
    case account do
      %{account_type: type, category_name: name} when type != name ->
        "#{type}: #{format_category_name(name)}"

      %{category_name: name} ->
        format_category_name(name)

      %{identifier: identifier} ->
        identifier

      _ ->
        "N/A"
    end
  end

  defp format_category_name(name) do
    name
    |> String.replace("_", " ")
  end

  defp format_money(%Money{amount: amount, currency: currency}) do
    "#{currency} #{Decimal.to_string(amount)}"
  end

  defp format_money(_), do: "N/A"
end
