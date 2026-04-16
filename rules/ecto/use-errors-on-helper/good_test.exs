# EXPECTED: passes
Mix.install([:ecto])

ExUnit.start(autorun: true)

defmodule ErrorsOnHelper.User do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :email, :string
    field :username, :string
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :username])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:username, min: 3, max: 20)
  end
end

defmodule UseErrorsOnHelperGoodTest do
  use ExUnit.Case, async: true

  alias ErrorsOnHelper.User

  # Clean helper: normalises changeset errors to %{field => [message, ...]}
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp changeset(attrs), do: User.changeset(%User{}, attrs)

  test "email is required" do
    errors = errors_on(changeset(%{name: "Alice"}))
    assert "can't be blank" in errors.email
  end

  test "name is required" do
    errors = errors_on(changeset(%{email: "a@b.com"}))
    assert "can't be blank" in errors.name
  end

  test "email must have @ symbol" do
    errors = errors_on(changeset(%{name: "Alice", email: "notvalid"}))
    assert errors.email != []
  end

  test "username must be at least 3 characters" do
    errors = errors_on(changeset(%{name: "Alice", email: "a@b.com", username: "ab"}))
    assert errors.username != []
  end

  test "valid changeset produces no errors" do
    errors = errors_on(changeset(%{name: "Alice", email: "alice@example.com", username: "alice"}))
    assert errors == %{}
  end
end
