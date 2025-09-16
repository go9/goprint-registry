defmodule GoprintRegistry.Services.ClientRegistration do
  @moduledoc """
  Service module for handling client registration and authentication.
  Extracts complex registration logic from the controller layer.
  """

  alias GoprintRegistry.{Clients, Accounts}
  alias Phoenix.Token
  alias GoprintRegistryWeb.Endpoint
  require Logger

  @doc """
  Registers a new desktop client or updates an existing one.
  Returns {:ok, response_data} or {:error, reason}
  """
  def register(params, ip_address) do
    attrs = build_registration_attrs(params)
    
    case Clients.create_client(attrs, ip_address) do
      {:ok, client} ->
        handle_successful_registration(client, params, attrs.client_secret)
      
      {:error, changeset} ->
        handle_registration_error(changeset, params, ip_address)
    end
  end

  @doc """
  Authenticates a client and returns a WebSocket token.
  """
  def authenticate(client_id, client_secret, params, ip_address) do
    with {:ok, client} <- get_and_validate_client(client_id, client_secret),
         :ok <- update_client_metadata(client, params),
         :ok <- log_ip_if_present(client_id, ip_address) do
      
      token = generate_ws_token(client_id)
      
      {:ok, %{
        success: true,
        ws_token: token,
        client_id: client.id,
        expires_in: 600  # 10 minutes
      }}
    else
      {:error, :not_found} ->
        {:error, :unauthorized, "Invalid credentials"}
      
      {:error, :no_secret} ->
        {:error, :unauthorized, "Client needs to re-register for security update"}
      
      {:error, :invalid_secret} ->
        {:error, :unauthorized, "Invalid credentials"}
      
      error ->
        error
    end
  end

  @doc """
  Generates a WebSocket authentication token for a client.
  """
  def generate_ws_token(client_id) do
    Token.sign(Endpoint, "ws_client", %{
      client_id: client_id,
      authenticated_at: DateTime.utc_now()
    })
  end

  # Private functions

  defp build_registration_attrs(params) do
    mac_address = extract_mac_address(params)
    client_secret = generate_client_secret()
    
    %{
      api_name: params["api_name"] || "Desktop Client",
      mac_address: mac_address,
      operating_system: params["operating_system"] || params["os"] || params["os_name"],
      app_version: params["app_version"] || params["version"],
      client_secret_hash: Bcrypt.hash_pwd_salt(client_secret),
      client_secret: client_secret  # Temporary, not saved to DB
    }
  end

  defp extract_mac_address(params) do
    mac = params["mac_address"] || params["mac"] || params["macAddress"]
    
    case mac do
      nil -> "unknown:" <> (params["client_id"] || Ecto.UUID.generate())
      "" -> "unknown:" <> (params["client_id"] || Ecto.UUID.generate())
      mac -> String.trim(to_string(mac))
    end
  end

  defp generate_client_secret do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp handle_successful_registration(client, params, client_secret) do
    # Auto-associate with user if token provided
    maybe_associate_user(params["user_token"], client.id)
    
    ws_token = generate_ws_token(client.id)
    
    {:ok, %{
      success: true,
      client_id: client.id,
      client_secret: client_secret,
      ws_token: ws_token,
      registered_at: client.registered_at
    }}
  end

  defp handle_registration_error(changeset, params, ip_address) do
    if has_mac_address_error?(changeset) do
      handle_existing_client_update(params, ip_address)
    else
      {:error, :bad_request, format_changeset_errors(changeset)}
    end
  end

  defp has_mac_address_error?(changeset) do
    Keyword.has_key?(changeset.errors, :mac_address)
  end

  defp handle_existing_client_update(params, ip_address) do
    mac_address = extract_mac_address(params)
    
    case Clients.get_client_by_mac_address(mac_address) do
      nil ->
        {:error, :bad_request, "Invalid registration"}
      
      client ->
        update_existing_client(client, params, ip_address)
    end
  end

  defp update_existing_client(client, params, ip_address) do
    new_secret = generate_client_secret()
    
    update_attrs = %{
      client_secret_hash: Bcrypt.hash_pwd_salt(new_secret),
      operating_system: params["operating_system"] || params["os"],
      app_version: params["app_version"] || params["version"]
    }
    
    case Clients.update_client(client, update_attrs) do
      {:ok, updated_client} ->
        if ip_address, do: Clients.log_ip_address(updated_client.id, ip_address)
        maybe_associate_user(params["user_token"], updated_client.id)
        
        ws_token = generate_ws_token(updated_client.id)
        
        {:ok, %{
          success: true,
          already_registered: true,
          client_id: updated_client.id,
          client_secret: new_secret,
          ws_token: ws_token,
          registered_at: updated_client.registered_at
        }}
      
      {:error, _} ->
        {:error, :bad_request, "Failed to update client"}
    end
  end

  defp maybe_associate_user(nil, _client_id), do: :ok
  defp maybe_associate_user(user_token, client_id) do
    case Accounts.get_user_by_session_token(user_token) do
      {user, _} -> 
        Clients.associate_user_with_client(user.id, client_id)
        :ok
      _ -> 
        :ok
    end
  end

  defp get_and_validate_client(client_id, client_secret) do
    case Clients.get_client(client_id) do
      nil ->
        {:error, :not_found}
      
      %{client_secret_hash: nil} ->
        {:error, :no_secret}
      
      client ->
        if Bcrypt.verify_pass(client_secret, client.client_secret_hash) do
          {:ok, client}
        else
          {:error, :invalid_secret}
        end
    end
  end

  defp update_client_metadata(client, params) do
    os = params["operating_system"] || params["os"]
    app_version = params["app_version"] || params["version"]
    
    if os || app_version do
      attrs = %{}
      |> maybe_put(:operating_system, os)
      |> maybe_put(:app_version, app_version)
      
      case Clients.update_client(client, attrs) do
        {:ok, _} -> :ok
        error -> error
      end
    else
      :ok
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp log_ip_if_present(_client_id, nil), do: :ok
  defp log_ip_if_present(client_id, ip_address) do
    Clients.log_ip_address(client_id, ip_address)
    :ok
  end

  defp format_changeset_errors(changeset) do
    "Registration failed: #{inspect(changeset.errors)}"
  end
end