# EXPECTED: passes
Mix.install([:ecto])

ExUnit.start(autorun: true)

# Simulated context module that builds a Multi pipeline
defmodule MultiGood.Accounts do
  def register_user_multi(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:validate_attrs, fn _repo, _changes ->
      if attrs[:email], do: {:ok, attrs}, else: {:error, :missing_email}
    end)
    |> Ecto.Multi.insert(:user, fn _changes ->
      # In real code this would be a changeset; placeholder here for structure test
      %{email: attrs[:email]}
    end)
    |> Ecto.Multi.run(:audit_log, fn _repo, %{user: user} ->
      {:ok, %{action: "created", subject: user}}
    end)
    |> Ecto.Multi.run(:send_welcome_email, fn _repo, _changes ->
      {:ok, :email_sent}
    end)
  end
end

defmodule MultiUnitTestGoodTest do
  use ExUnit.Case, async: true

  alias MultiGood.Accounts

  test "register_user_multi includes all expected operation names" do
    multi = Accounts.register_user_multi(%{email: "alice@example.com"})
    names = multi |> Ecto.Multi.to_list() |> Keyword.keys()

    assert :validate_attrs in names
    assert :user in names
    assert :audit_log in names
    assert :send_welcome_email in names
  end

  test "register_user_multi has operations in correct order" do
    multi = Accounts.register_user_multi(%{email: "alice@example.com"})
    names = multi |> Ecto.Multi.to_list() |> Keyword.keys()

    validate_idx = Enum.find_index(names, &(&1 == :validate_attrs))
    user_idx = Enum.find_index(names, &(&1 == :user))
    audit_idx = Enum.find_index(names, &(&1 == :audit_log))

    assert validate_idx < user_idx
    assert user_idx < audit_idx
  end

  test "to_list returns all 4 operations" do
    multi = Accounts.register_user_multi(%{email: "alice@example.com"})
    assert length(Ecto.Multi.to_list(multi)) == 4
  end
end
