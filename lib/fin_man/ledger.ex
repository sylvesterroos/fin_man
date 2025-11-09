defmodule FinMan.Ledger do
  use Ash.Domain,
    otp_app: :fin_man

  resources do
    resource FinMan.Ledger.Account
    resource FinMan.Ledger.Balance
    resource FinMan.Ledger.Transfer
  end
end
