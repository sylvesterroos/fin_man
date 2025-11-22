defmodule FinManWeb.TransferLive do
  use FinManWeb, :live_view
  alias FinMan.Ledger

  @impl true
  def mount(_params, _session, socket) do
    # Get income and expense accounts for the dropdowns
    {:ok, income_accounts} = Ledger.get_income_accounts()
    {:ok, expense_accounts} = Ledger.get_expense_accounts()

    socket
    |> assign(:income_accounts, income_accounts)
    |> assign(:expense_accounts, expense_accounts)
    |> assign(:active_tab, :income)
    |> assign_income_form()
    |> assign_expense_form()
    |> ok()
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    socket
    |> assign(:active_tab, String.to_existing_atom(tab))
    |> noreply()
  end

  @impl true
  def handle_event("validate_income", %{"income" => params}, socket) do
    form =
      AshPhoenix.Form.for_create(Ledger.Transfer, :transfer,
        domain: Ledger,
        forms: [auto?: true]
      )
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    socket
    |> assign(:income_form, form)
    |> noreply()
  end

  @impl true
  def handle_event("submit_income", %{"income" => params}, socket) do
    case Ledger.create_income_transfer(params) do
      {:ok, _transfer} ->
        socket
        |> put_flash(:info, "Income transfer created successfully!")
        |> push_navigate(to: ~p"/")
        |> noreply()

      {:error, error} ->
        form =
          AshPhoenix.Form.for_create(Ledger.Transfer, :transfer,
            domain: Ledger,
            forms: [auto?: true]
          )
          |> AshPhoenix.Form.add_error(error)
          |> to_form()

        socket
        |> assign(:income_form, form)
        |> noreply()
    end
  end

  @impl true
  def handle_event("validate_expense", %{"expense" => params}, socket) do
    form =
      AshPhoenix.Form.for_create(Ledger.Transfer, :transfer,
        domain: Ledger,
        forms: [auto?: true]
      )
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    socket
    |> assign(:expense_form, form)
    |> noreply()
  end

  @impl true
  def handle_event("submit_expense", %{"expense" => params}, socket) do
    case Ledger.create_expense_transfer(params) do
      {:ok, _transfer} ->
        socket
        |> put_flash(:info, "Expense transfer created successfully!")
        |> push_navigate(to: ~p"/")
        |> noreply()

      {:error, error} ->
        form =
          AshPhoenix.Form.for_create(Ledger.Transfer, :transfer,
            domain: Ledger,
            forms: [auto?: true]
          )
          |> AshPhoenix.Form.add_error(error)
          |> to_form()

        socket
        |> assign(:expense_form, form)
        |> noreply()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header --%>
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold">New Transfer</h1>
        <.link navigate="/" class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="size-4 mr-2" /> Back to Overview
        </.link>
      </div>

      <%!-- Tab Navigation --%>
      <div class="flex gap-2 border-b border-gray-200 dark:border-gray-700">
        <button
          type="button"
          phx-click="switch_tab"
          phx-value-tab="income"
          class={[
            "px-4 py-2 font-medium transition-colors",
            if(@active_tab == :income,
              do: "border-b-2 border-primary text-primary",
              else: "text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
            )
          ]}
        >
          Incoming Transfer (Income)
        </button>
        <button
          type="button"
          phx-click="switch_tab"
          phx-value-tab="expense"
          class={[
            "px-4 py-2 font-medium transition-colors",
            if(@active_tab == :expense,
              do: "border-b-2 border-primary text-primary",
              else: "text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
            )
          ]}
        >
          Outgoing Transfer (Expense)
        </button>
      </div>

      <%!-- Income Form --%>
      <div :if={@active_tab == :income}>
        <.card variant="outline" padding="large">
          <.card_title title="Record Income" size="large" />
          <.card_content>
            <.form
              for={@income_form}
              id="income-form"
              phx-change="validate_income"
              phx-submit="submit_income"
            >
              <div class="space-y-4">
                <.native_select
                  field={@income_form[:from_account_id]}
                  name="income[from_account_id]"
                  label="Income Category"
                  color="primary"
                  variant="default"
                  size="large"
                  required
                >
                  <:option value="">Select a category</:option>
                  <:option :for={account <- @income_accounts} value={account.id}>
                    {String.replace(account.category_name, "_", " ")}
                  </:option>
                </.native_select>

                <.number_field
                  field={@income_form[:amount]}
                  name="income[amount]"
                  label="Amount (EUR)"
                  color="primary"
                  variant="default"
                  size="large"
                  placeholder="0.00"
                  step="0.01"
                  min="0.01"
                  required
                />

                <.text_field
                  field={@income_form[:description]}
                  name="income[description]"
                  label="Description"
                  color="primary"
                  variant="default"
                  size="large"
                  placeholder="Enter a description (optional)"
                />

                <.date_time_field
                  field={@income_form[:date]}
                  name="income[date]"
                  label="Date"
                  type="date"
                  color="primary"
                  variant="default"
                  size="large"
                  value={Date.utc_today() |> Date.to_string()}
                  required
                />

                <div class="flex gap-3 pt-4">
                  <.button type="submit" variant="default" color="primary" size="large">
                    Create Income Transfer
                  </.button>
                  <.button_link navigate="/" variant="outline" color="secondary" size="large">
                    Cancel
                  </.button_link>
                </div>
              </div>
            </.form>
          </.card_content>
        </.card>
      </div>

      <%!-- Expense Form --%>
      <div :if={@active_tab == :expense}>
        <.card variant="outline" padding="large">
          <.card_title title="Record Expense" size="large" />
          <.card_content>
            <.form
              for={@expense_form}
              id="expense-form"
              phx-change="validate_expense"
              phx-submit="submit_expense"
            >
              <div class="space-y-4">
                <.native_select
                  field={@expense_form[:to_account_id]}
                  name="expense[to_account_id]"
                  label="Expense Category"
                  color="primary"
                  variant="default"
                  size="large"
                  required
                >
                  <:option value="">Select a category</:option>
                  <:option :for={account <- @expense_accounts} value={account.id}>
                    {String.replace(account.category_name, "_", " ")}
                  </:option>
                </.native_select>

                <.number_field
                  field={@expense_form[:amount]}
                  name="expense[amount]"
                  label="Amount (EUR)"
                  color="primary"
                  variant="default"
                  size="large"
                  placeholder="0.00"
                  step="0.01"
                  min="0.01"
                  required
                />

                <.text_field
                  field={@expense_form[:description]}
                  name="expense[description]"
                  label="Description"
                  color="primary"
                  variant="default"
                  size="large"
                  placeholder="Enter a description (optional)"
                />

                <.date_time_field
                  field={@expense_form[:date]}
                  name="expense[date]"
                  label="Date"
                  type="date"
                  color="primary"
                  variant="default"
                  size="large"
                  value={Date.utc_today() |> Date.to_string()}
                  required
                />

                <div class="flex gap-3 pt-4">
                  <.button type="submit" variant="default" color="primary" size="large">
                    Create Expense Transfer
                  </.button>
                  <.button_link navigate="/" variant="outline" color="secondary" size="large">
                    Cancel
                  </.button_link>
                </div>
              </div>
            </.form>
          </.card_content>
        </.card>
      </div>
    </div>
    """
  end

  defp assign_income_form(socket) do
    form =
      AshPhoenix.Form.for_create(Ledger.Transfer, :transfer,
        domain: Ledger,
        forms: [auto?: true]
      )
      |> to_form()

    assign(socket, :income_form, form)
  end

  defp assign_expense_form(socket) do
    form =
      AshPhoenix.Form.for_create(Ledger.Transfer, :transfer,
        domain: Ledger,
        forms: [auto?: true]
      )
      |> to_form()

    assign(socket, :expense_form, form)
  end
end
