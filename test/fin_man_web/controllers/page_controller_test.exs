defmodule FinManWeb.TransferLiveTest do
  use FinManWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    # Create required accounts for the LiveView, handling duplicates
    main_account =
      case FinMan.Ledger.get_account_by_identifier("Assets:Account") do
        {:ok, account} ->
          account

        {:error, _} ->
          {:ok, account} = FinMan.Ledger.open(%{identifier: "Assets:Account", currency: "EUR"})
          account
      end

    income_account =
      case FinMan.Ledger.get_account_by_identifier("Income:Salary") do
        {:ok, account} ->
          account

        {:error, _} ->
          {:ok, account} = FinMan.Ledger.open(%{identifier: "Income:Salary", currency: "EUR"})
          account
      end

    expense_account =
      case FinMan.Ledger.get_account_by_identifier("Expenses:Groceries") do
        {:ok, account} ->
          account

        {:error, _} ->
          {:ok, account} =
            FinMan.Ledger.open(%{identifier: "Expenses:Groceries", currency: "EUR"})

          account
      end

    %{
      main_account: main_account,
      income_account: income_account,
      expense_account: expense_account
    }
  end

  describe "Overview page" do
    test "GET / displays overview", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Financial Overview"
      assert html =~ "Main Account Balance"
      assert html =~ "Income for"
      assert html =~ "Expenses for"
    end

    test "displays spending by category", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "h1", "Financial Overview")
      assert has_element?(view, "[class*='card']")
    end

    test "has link to new transfer page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "a[href='/transfers/new']", "New Transfer")
    end
  end

  describe "Transfer page" do
    test "GET /transfers/new displays form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transfers/new")
      assert html =~ "New Transfer"
      assert html =~ "Incoming Transfer (Income)"
      assert html =~ "Outgoing Transfer (Expense)"
    end

    test "can toggle between income and expense tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transfers/new")

      # Default is income tab
      assert has_element?(view, "button", "Incoming Transfer (Income)")
      assert has_element?(view, "button", "Outgoing Transfer (Expense)")

      # Click expense tab
      view |> element("button", "Outgoing Transfer (Expense)") |> render_click()
      assert has_element?(view, "#expense-form")

      # Click back to income tab
      view |> element("button", "Incoming Transfer (Income)") |> render_click()
      assert has_element?(view, "#income-form")
    end

    test "displays income form with correct fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transfers/new")
      assert has_element?(view, "#income-form")
      assert has_element?(view, "select[name='income[from_account_id]']")
      assert has_element?(view, "input[name='income[amount]']")
      assert has_element?(view, "input[name='income[description]']")
      assert has_element?(view, "input[name='income[date]']")
    end

    test "displays expense form with correct fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transfers/new")

      # Switch to expense tab
      view |> element("button", "Outgoing Transfer (Expense)") |> render_click()

      assert has_element?(view, "#expense-form")
      assert has_element?(view, "select[name='expense[to_account_id]']")
      assert has_element?(view, "input[name='expense[amount]']")
      assert has_element?(view, "input[name='expense[description]']")
      assert has_element?(view, "input[name='expense[date]']")
    end
  end
end
