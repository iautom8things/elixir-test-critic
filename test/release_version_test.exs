defmodule TestCritic.ReleaseVersionTest do
  use ExUnit.Case, async: true

  test "the plugin and its marketplace entry match the Mix version" do
    plugin = manifest("plugin")
    marketplace = manifest("marketplace")
    [entry] = Enum.filter(marketplace["plugins"], &(&1["name"] == plugin["name"]))
    version = Mix.Project.config()[:version]

    assert plugin["version"] == version
    assert entry["version"] == version
  end

  defp manifest(name) do
    Path.expand("../.claude-plugin/#{name}.json", __DIR__)
    |> File.read!()
    |> Jason.decode!()
  end
end
