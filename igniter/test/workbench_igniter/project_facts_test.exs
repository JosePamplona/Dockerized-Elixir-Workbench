defmodule WorkbenchIgniter.ProjectFactsTest do
  @moduledoc false

  # What a cartridge reads off the project instead of asking: its
  # display name and its repository (WorkbenchIgniter.Feature).

  use ExUnit.Case, async: true

  alias WorkbenchIgniter.Feature

  describe "browsable/1" do
    test "a remote is its repository's https page" do
      for remote <- [
            "git@github.com:acme/app.git",
            "ssh://git@github.com:22/acme/app.git",
            "https://user@github.com/acme/app.git",
            "https://github.com/acme/app/"
          ] do
        assert Feature.browsable(remote) == "https://github.com/acme/app", remote
      end

      assert Feature.browsable("git@gitlab.com:acme/group/app.git") ==
               "https://gitlab.com/acme/group/app"
    end

    test "what is not host/owner/repo is nothing" do
      for remote <- ["/srv/git/app.git", "file:///srv/app.git", "git@github.com:app.git"] do
        assert Feature.browsable(remote) == nil, remote
      end
    end
  end

  describe "git_origin/1" do
    @describetag :tmp_dir

    defp git(dir, args), do: {_, 0} = System.cmd("git", ["-C", dir | args])

    test "the origin of the repository rooted at the directory", %{tmp_dir: dir} do
      git(dir, ["init", "-q"])
      assert Feature.git_origin(dir) == nil

      git(dir, ["remote", "add", "origin", "git@github.com:acme/app.git"])
      assert Feature.git_origin(dir) == "https://github.com/acme/app"
    end

    test "a directory inside another repository does not take its remote", %{tmp_dir: dir} do
      git(dir, ["init", "-q"])
      git(dir, ["remote", "add", "origin", "git@github.com:acme/workbench.git"])
      project = Path.join(dir, "_workspaces/app")
      File.mkdir_p!(project)

      assert Feature.git_origin(project) == nil
    end

    test "no repository at all", %{tmp_dir: dir} do
      # tmp_dir sits under the igniter's own repository: the prefix is
      # not empty, so its remote is not taken either.
      assert Feature.git_origin(dir) == nil
    end
  end
end
