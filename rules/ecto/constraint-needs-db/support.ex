defmodule ConstraintNeedsDb.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "constraint_users" do
    field :email, :string
    field :name, :string
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end

defmodule ConstraintNeedsDb.Migration do
  use Ecto.Migration

  def change do
    create table(:constraint_users) do
      add :email, :string, null: false
      add :name, :string
      timestamps()
    end

    create unique_index(:constraint_users, [:email])
  end
end
