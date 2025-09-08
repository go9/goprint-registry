#!/usr/bin/env elixir

# Test script for API authentication
Mix.install([
  {:req, "~> 0.4.0"},
  {:jason, "~> 1.4"}
])

alias GoprintRegistry.Accounts

# Start the application
Application.ensure_all_started(:goprint_registry)

# Create a test user if not exists
test_email = "api_test@example.com"
test_password = "TestPassword123!"

IO.puts("Setting up test user...")
user = case Accounts.get_user_by_email(test_email) do
  nil ->
    {:ok, user} = Accounts.register_user(%{
      email: test_email,
      password: test_password
    })
    IO.puts("Created test user: #{user.email}")
    user
  existing ->
    IO.puts("Using existing test user: #{existing.email}")
    existing
end

# Create an API token
IO.puts("\nCreating API token...")
token = Accounts.create_user_api_token(user, "Test API Key")
IO.puts("Generated token: #{token}")

# Test the API authentication
base_url = "http://localhost:4002"

IO.puts("\n--- Testing API Authentication ---")

# Test without authentication
IO.puts("\n1. Testing without authentication...")
response = Req.get!("#{base_url}/api/status")
IO.puts("   Status: #{response.status}")
IO.puts("   Response: #{inspect(response.body)}")

# Test with API token
IO.puts("\n2. Testing with API token...")
headers = [
  {"Authorization", "Bearer #{token}"}
]

# Create a test print job request
print_job_params = %{
  "client_id" => "test-client-123",
  "printer_id" => "test-printer",
  "data_base64" => Base.encode64("Test print content"),
  "mime" => "text/plain",
  "filename" => "test.txt"
}

response = Req.post!("#{base_url}/api/print_jobs/file", 
  json: print_job_params,
  headers: headers
)

IO.puts("   Status: #{response.status}")
IO.puts("   Response: #{inspect(response.body)}")

# List API tokens to verify
IO.puts("\n3. Listing API tokens for user...")
tokens = Accounts.list_user_api_tokens(user)
for token <- tokens do
  IO.puts("   - #{token.name} (ID: #{token.id})")
  IO.puts("     Created: #{token.inserted_at}")
  IO.puts("     Last used: #{token.last_used_at || "Never"}")
end

IO.puts("\n✓ API authentication test complete!")