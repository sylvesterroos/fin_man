defmodule FinManWeb.PageController do
  use FinManWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
