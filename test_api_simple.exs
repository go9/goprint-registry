#!/usr/bin/env elixir

# Simple test script for API authentication
alias GoprintRegistry.Accounts
alias GoprintRegistry.Clients

# Create a test user
test_email = "api_test_#{:rand.uniform(10000)}@example.com"
test_password = "TestPassword123!"

IO.puts("Creating test user...")
{:ok, user} = Accounts.register_user(%{
  email: test_email,
  password: test_password
})
IO.puts("Created user: #{user.email}")

# Create an API token
IO.puts("\nCreating API token...")
token = Accounts.create_user_api_token(user, "Test API Key")
IO.puts("Generated token: #{token}")

# Create a test client with proper UUID
IO.puts("\nCreating test client...")
client_attrs = %{
  api_name: "Test Client",
  user_id: user.id,
  os_type: "macos",
  version: "1.0.0",
  mac_address: "00:11:22:#{:rand.uniform(99) |> Integer.to_string() |> String.pad_leading(2, "0")}:#{:rand.uniform(99) |> Integer.to_string() |> String.pad_leading(2, "0")}:#{:rand.uniform(99) |> Integer.to_string() |> String.pad_leading(2, "0")}"
}
{:ok, client} = Clients.create_client(client_attrs)
IO.puts("Created client with ID: #{client.id}")

# Associate user with client
IO.puts("Associating user with client...")
{:ok, _} = Clients.associate_user_with_client(user.id, client.id)
IO.puts("User associated with client")

# Test the API endpoint with curl
base_url = "http://localhost:4002"

IO.puts("\n--- Testing API Authentication ---")

# Test without authentication
IO.puts("\n1. Testing without authentication...")
{output, _} = System.cmd("curl", [
  "-s", 
  "-X", "POST",
  "-H", "Content-Type: application/json",
  "#{base_url}/api/print_jobs/test",
  "-d", Jason.encode!(%{
    "client_id" => client.id,
    "printer_id" => "test-printer"
  })
])
IO.puts("   Response: #{output}")

# Test with API token
IO.puts("\n2. Testing with API token...")
{output, _} = System.cmd("curl", [
  "-s",
  "-X", "POST",
  "-H", "Content-Type: application/json",
  "-H", "Authorization: Bearer #{token}",
  "#{base_url}/api/print_jobs/test",
  "-d", Jason.encode!(%{
    "client_id" => client.id,
    "printer_id" => "test-printer"
  })
])
IO.puts("   Response: #{output}")

# Verify token was marked as used
IO.puts("\n3. Checking if token was marked as used...")
tokens = Accounts.list_user_api_tokens(user)
for token <- tokens do
  IO.puts("   - #{token.name}: Last used = #{token.last_used_at || "Never"}")
end

IO.puts("\n✓ API authentication test complete!")