defmodule FinManWeb.TransferLiveTest do
  use FinManWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    # Create required accounts for the LiveView
    {:ok, main_account} = FinMan.Ledger.open(%{identifier: "Assets:Account", currency: "EUR"})
    {:ok, _income} = FinMan.Ledger.open(%{identifier: "Income:Salary", currency: "EUR"})
    {:ok, _expense} = FinMan.Ledger.open(%{identifier: "Expenses:Groceries", currency: "EUR"})

    %{main_account: main_account}
  end

  test "GET /", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Transfers"
    assert html =~ "New Transfer"
    assert html =~ "Recent Transfers"
  end

  test "displays transfer forms", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "h1", "Transfers")
    assert has_element?(view, "h2", "New Transfer")
    assert has_element?(view, "h2", "Recent Transfers")
  end

  test "can toggle between incoming and outgoing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    # Default is incoming - check that both buttons exist
    assert has_element?(view, "button", "Incoming")
    assert has_element?(view, "button", "Outgoing")

    # Click outgoing
    view |> element("button", "Outgoing") |> render_click()
    assert has_element?(view, "button", "Outgoing")
  end
end
