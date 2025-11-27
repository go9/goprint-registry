defmodule GoprintRegistry.GithubReleases do
  @moduledoc """
  Fetches and caches the latest release info from GitHub.
  """
  use GenServer

  @github_api_url "https://api.github.com/repos/go9/goprint/releases/latest"
  @cache_ttl_ms :timer.minutes(5)
  @fallback_version "1.0.0"

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Returns the latest release info, fetching from GitHub if cache is stale.
  """
  def get_latest_release do
    GenServer.call(__MODULE__, :get_latest_release)
  end

  # Server callbacks

  @impl true
  def init(_) do
    {:ok, %{release: nil, fetched_at: nil}}
  end

  @impl true
  def handle_call(:get_latest_release, _from, state) do
    if cache_valid?(state) do
      {:reply, state.release, state}
    else
      case fetch_from_github() do
        {:ok, release} ->
          new_state = %{release: release, fetched_at: System.monotonic_time(:millisecond)}
          {:reply, release, new_state}

        {:error, _reason} ->
          # Return cached data if available, otherwise fallback
          release = state.release || fallback_release()
          {:reply, release, state}
      end
    end
  end

  # Private functions

  defp cache_valid?(%{release: nil}), do: false

  defp cache_valid?(%{fetched_at: fetched_at}) do
    now = System.monotonic_time(:millisecond)
    now - fetched_at < @cache_ttl_ms
  end

  defp fetch_from_github do
    headers = [{"accept", "application/vnd.github.v3+json"}] ++ auth_header()

    case Req.get(@github_api_url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_release(body)}

      {:ok, %{status: status}} ->
        {:error, "GitHub API returned status #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp auth_header do
    case System.get_env("GITHUB_TOKEN") do
      nil -> []
      token -> [{"authorization", "Bearer #{token}"}]
    end
  end

  defp parse_release(body) do
    assets = body["assets"] || []

    %{
      version: body["tag_name"] || @fallback_version,
      published_at: body["published_at"],
      assets: %{
        mac_dmg: find_asset(assets, ~r/\.dmg$/i),
        mac_arm64_dmg: find_asset(assets, ~r/-arm64\.dmg$/i),
        mac_x64_dmg: find_asset(assets, ~r/GoPrint-[\d.]+\.dmg$/i),
        mac_zip: find_asset(assets, ~r/mac.*\.zip$/i),
        windows_exe: find_asset(assets, ~r/\.exe$/i),
        linux_deb: find_asset(assets, ~r/\.deb$/i),
        linux_rpm: find_asset(assets, ~r/\.rpm$/i),
        linux_appimage: find_asset(assets, ~r/\.AppImage$/i)
      }
    }
  end

  defp find_asset(assets, pattern) do
    Enum.find_value(assets, fn asset ->
      if Regex.match?(pattern, asset["name"]) do
        %{
          name: asset["name"],
          url: asset["browser_download_url"],
          size: asset["size"]
        }
      end
    end)
  end

  defp fallback_release do
    %{
      version: @fallback_version,
      published_at: nil,
      assets: %{
        mac_dmg: nil,
        mac_arm64_dmg: nil,
        mac_x64_dmg: nil,
        mac_zip: nil,
        windows_exe: nil,
        linux_deb: nil,
        linux_rpm: nil,
        linux_appimage: nil
      }
    }
  end
end
