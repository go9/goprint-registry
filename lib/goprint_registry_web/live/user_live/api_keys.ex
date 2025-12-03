defmodule GoprintRegistryWeb.UserLive.ApiKeys do
  use GoprintRegistryWeb, :live_view

  alias GoprintRegistry.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    api_keys = Accounts.list_user_api_tokens(user)

    {:ok,
     socket
     |> assign(:page_title, "API Keys")
     |> assign(:api_keys, api_keys)
     |> assign(:show_modal, false)
     |> assign(:new_key_name, "")
     |> assign(:generated_token, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8" id="api-keys-page" phx-hook="UrlOpener">
      <!-- Header Section -->
      <div class="space-y-4 mb-8">
        <!-- API Docs Link -->
        <div class="flex justify-start">
          <.link href="/api/docs" target="_blank">
            <.button type="button" variant="ghost" size="sm" color="info">
              <.icon name="hero-book-open" class="-ml-0.5 mr-1.5 h-4 w-4" />
              View API Documentation
              <.icon name="hero-arrow-top-right-on-square" class="ml-1.5 h-3.5 w-3.5" />
            </.button>
          </.link>
        </div>

        <!-- Action Bar -->
        <div class="flex justify-between items-center gap-6">
          <p class="text-sm text-muted-foreground">
            Manage API keys for programmatic access to the GoPrint API
          </p>
          <.button type="button" variant="solid" color="primary" phx-click="open_modal" class="shrink-0">
            <.icon name="hero-plus" class="-ml-1 mr-2 h-5 w-5" />
            Create New Key
          </.button>
        </div>
      </div>

      <!-- API Keys Table -->
      <div class="mt-6 overflow-hidden shadow ring-1 ring-black/5 dark:ring-white/10 sm:rounded-lg">
        <%= if @api_keys == [] do %>
          <div class="text-center py-12 bg-card">
            <.icon name="hero-key" class="mx-auto h-12 w-12 text-muted-foreground" />
            <h3 class="mt-2 text-sm font-medium text-foreground">No API keys</h3>
            <p class="mt-1 text-sm text-muted-foreground">
              Get started by creating a new API key.
            </p>
          </div>
        <% else %>
          <table class="min-w-full divide-y divide-base">
            <thead class="bg-muted/50">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Name
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Created
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Last Used
                </th>
                <th scope="col" class="relative px-6 py-3">
                  <span class="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody class="bg-card divide-y divide-base">
              <%= for key <- @api_keys do %>
                <tr class="hover:bg-muted/50">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-foreground"><%= key.name %></div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    <%= format_date(key.inserted_at) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <%= if key.last_used_at do %>
                      <.badge color={last_used_color(key.last_used_at)}>
                        <%= format_last_used(key.last_used_at) %>
                      </.badge>
                    <% else %>
                      <.badge color="warning">Never used</.badge>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <.button
                      type="button"
                      variant="ghost"
                      size="sm"
                      color="danger"
                      phx-click="revoke"
                      phx-value-id={key.id}
                      data-confirm="Are you sure you want to revoke this API key? This action cannot be undone."
                    >
                      Revoke
                    </.button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>

    </div>

    <!-- Create Modal -->
    <%= if @show_modal do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div class="fixed inset-0 bg-black/50 transition-opacity" phx-click="close_modal"></div>
          <div class="relative transform overflow-hidden rounded-lg bg-card border border-base text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
            <.form for={%{}} phx-submit="create_key">
              <div class="px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-primary/10 sm:mx-0 sm:h-10 sm:w-10">
                    <.icon name="hero-key" class="h-6 w-6 text-primary" />
                  </div>
                  <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left flex-1">
                    <h3 class="text-base font-semibold leading-6 text-foreground" id="modal-title">
                      Create New API Key
                    </h3>
                    <div class="mt-4">
                      <.input
                        type="text"
                        name="key_name"
                        label="Key Name"
                        placeholder="e.g., Production App"
                        required
                      />
                      <p class="mt-2 text-sm text-muted-foreground">
                        Choose a descriptive name to help you identify this key later.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              <div class="bg-muted/50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
                <.button type="submit" variant="solid" color="primary" class="w-full sm:ml-3 sm:w-auto">
                  Generate Key
                </.button>
                <.button
                  type="button"
                  variant="outline"
                  phx-click="close_modal"
                  class="mt-3 w-full sm:mt-0 sm:w-auto"
                >
                  Cancel
                </.button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    <% end %>

    <!-- Success Modal with Generated Token -->
    <%= if @generated_token do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="success-modal-title" role="dialog" aria-modal="true">
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div class="fixed inset-0 bg-black/50 transition-opacity" phx-click="close_success"></div>
          <div class="relative transform overflow-hidden rounded-lg bg-card border border-base text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-2xl">
            <div class="px-4 pb-4 pt-5 sm:p-6">
              <div class="sm:flex sm:items-start">
                <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-success/10 sm:mx-0 sm:h-10 sm:w-10">
                  <.icon name="hero-check-circle" class="h-6 w-6 text-success" />
                </div>
                <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left flex-1">
                  <h3 class="text-base font-semibold leading-6 text-foreground" id="success-modal-title">
                    API Key Created Successfully
                  </h3>
                  <div class="mt-4">
                    <div class="rounded-md bg-warning/10 border border-warning/20 p-4 mb-4">
                      <div class="flex">
                        <div class="flex-shrink-0">
                          <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-warning" />
                        </div>
                        <div class="ml-3">
                          <p class="text-sm text-warning-foreground">
                            Make sure to copy your new API key now. You won't be able to see it again!
                          </p>
                        </div>
                      </div>
                    </div>
                    <div class="space-y-3">
                      <div>
                        <label class="block text-sm font-medium text-foreground mb-1">
                          Your new API key:
                        </label>
                        <div class="flex items-center space-x-2">
                          <code
                            id="generated-key"
                            class="flex-1 px-3 py-2 bg-muted border border-base rounded text-sm font-mono text-foreground select-all break-all"
                          >
                            <%= @generated_token %>
                          </code>
                          <.button
                            type="button"
                            id="copy-button"
                            phx-hook="CopyButton"
                            data-clipboard-text={@generated_token}
                            variant="outline"
                          >
                            <.icon name="hero-clipboard-document" class="h-4 w-4 mr-1" />
                            Copy
                          </.button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div class="bg-muted/50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
              <.button
                type="button"
                variant="solid"
                color="primary"
                phx-click="close_success"
                class="w-full sm:ml-3 sm:w-auto"
              >
                Done
              </.button>
              <.link href="/api/docs" target="_blank">
                <.button
                  type="button"
                  variant="outline"
                  class="mt-3 w-full sm:mt-0 sm:w-auto"
                >
                  <.icon name="hero-arrow-top-right-on-square" class="-ml-0.5 mr-2 h-4 w-4" />
                  Open API Docs
                </.button>
              </.link>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event("open_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  def handle_event("close_success", _, socket) do
    {:noreply, assign(socket, :generated_token, nil)}
  end

  def handle_event("create_key", %{"key_name" => name}, socket) do
    user = socket.assigns.current_scope.user
    token = Accounts.create_user_api_token(user, name)
    api_keys = Accounts.list_user_api_tokens(user)

    {:noreply,
     socket
     |> assign(:api_keys, api_keys)
     |> assign(:show_modal, false)
     |> assign(:generated_token, token)
     |> put_flash(:info, "API key created successfully. Make sure to copy it now!")}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    Accounts.delete_user_api_token(user.id, String.to_integer(id))
    api_keys = Accounts.list_user_api_tokens(user)

    {:noreply,
     socket
     |> assign(:api_keys, api_keys)
     |> put_flash(:info, "API key revoked successfully.")}
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_last_used(nil), do: "Never"
  defp format_last_used(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
    
    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604800 -> "#{div(diff, 86400)} days ago"
      true -> format_date(datetime)
    end
  end

  defp last_used_color(nil), do: "gray"
  defp last_used_color(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 86400 -> "success"
      diff < 604800 -> "gray"
      true -> "gray"
    end
  end
end