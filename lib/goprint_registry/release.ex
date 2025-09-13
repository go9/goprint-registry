defmodule GoprintRegistry.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :goprint_registry

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def reset_db do
    load_app()
    
    for repo <- repos() do
      # Drop the database
      repo.__adapter__.storage_down(repo.config())
      
      # Create the database
      repo.__adapter__.storage_up(repo.config())
      
      # Run migrations
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
      
      # Run seeds if they exist
      seed_script = priv_path_for(repo, "seeds.exs")
      if File.exists?(seed_script) do
        Code.eval_file(seed_script)
      end
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config(), :otp_app)
    
    IO.puts("Looking for priv dir for app: #{inspect(app)}")
    
    case :code.priv_dir(app) do
      {:error, _} ->
        # If :code.priv_dir/1 fails, build the path manually
        # This can happen in some release environments
        Path.join([Application.app_dir(app), "priv", "repo", filename])
      priv_dir ->
        Path.join([priv_dir, "repo", filename])
    end
  end
end