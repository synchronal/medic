defmodule Medic.Update do
  @moduledoc """
  Performs a list of commands to update a project.

  ## Usage

  `Medic.Update` is run from a shell script generated at `bin/dev/update`:

      elixir -r .medic/require.exs -e "Medic.Update.run()" $*

  ## Configuration

  See the guides for information on how to [Configure Update Checks](installation.html#configure-update-commands).
  """

  alias Medic.UI

  @documentation_url "https://hexdocs.pm/medic/installation.html#configure-update-commands"

  @doc "Runs the commands listed in `.medic/update.exs`."
  def run, do: read_commands() |> Enum.each(&run_command/1)

  defp run_command(:build_mix) do
    {output, 0} = System.cmd("mix", ["deps"])
    outdated = Medic.Support.Hex.split(output) |> Enum.filter(fn dep -> dep.status == :outdated end)

    if outdated == [] do
      UI.heading("Rebuilding mix deps", ["mix", "deps.compile"], inline: true)
      UI.skipped()
    else
      outdated_libs = outdated |> Enum.map(& &1.name)
      run_command(["Rebuilding mix deps", "mix", ["deps.compile" | outdated_libs]])
    end
  end

  defp run_command(:update_code), do: run_command(["Updating code", "git", ["pull", "--rebase"]])
  defp run_command(:update_mix), do: run_command(["Updating mix deps", "mix", ["deps.get"], [env: [{"MIX_QUIET", "true"}]]])
  defp run_command(:update_npm), do: run_command(["Updating npm deps", "npm", ["install", "--prefix", "assets"]])
  defp run_command(:build_npm), do: run_command(["Rebuilding JS", "npm", ["run", "build", "--prefix", "assets"]])
  defp run_command(:migrate), do: run_command(["Running migrations", "mix", ["ecto.migrate"]])
  defp run_command(:doctor), do: Medic.Doctor.run()
  defp run_command([description, command, args]), do: Medic.Cmd.run!(description, command, args)
  defp run_command([description, command, args, opts]), do: Medic.Cmd.run!(description, command, args, opts)

  defp read_commands do
    if File.exists?(".medic/update.exs") do
      case Code.eval_file(".medic/update.exs") do
        {commands, []} when is_list(commands) -> commands
        _ -> raise "Expected `.medic/update.exs` to be a list of commands. See #{@documentation_url}"
      end
    else
      raise "File `.medic/update.exs` not found. See #{@documentation_url}"
    end
  end
end
