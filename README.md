# FinMan

FinMan is a simple web app for tracking your income and expenses.

## Why?

This project started as an alternative to managing finances in a spreadsheet. Ironically, I later discovered that my banking app already automates this process, so FinMan is unlikely to see much further development.

I built FinMan to gain experience with the Ash framework, as well as to solve a personal problem. The app models financial data using `AshDoubleEntry`, an Ash extension for double-entry bookkeeping. The domain includes accounts, balances, and transfers, all powered by `AshDoubleEntry`.

## Development

To set up the development environment:

Open a shell with the required tools:
- Run `nix develop --impure` (the `--impure` flag is required for Devenv), or
- Use `direnv` by running `direnv allow`.

To start your Phoenix server:
- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Alternatively, you can use the predefined Devenv processes:
- Run `devenv up` to start both the database and the Phoenix server.
