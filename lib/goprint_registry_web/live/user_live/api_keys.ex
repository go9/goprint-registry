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
     |> assign(:generated_token, nil)
     |> assign(:filter, "")
     |> assign(:filtered_keys, api_keys)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8" id="api-keys-page" phx-hook="UrlOpener">
      <!-- Header section with Create button -->
      <div class="bg-white dark:bg-gray-800 shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <div class="sm:flex sm:items-center sm:justify-between">
            <div>
              <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white">
                API Keys
              </h3>
              <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                Manage API keys for programmatic access to the GoPrint Registry API
              </p>
            </div>
            <div class="mt-4 sm:mt-0 flex gap-2">
              <a
                href="/api/docs"
                target="_blank"
                class="inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 text-sm font-medium rounded-md text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                <svg class="-ml-1 mr-2 h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M9 4.804A7.968 7.968 0 005.5 4c-1.255 0-2.443.29-3.5.804v10A7.969 7.969 0 015.5 14c1.669 0 3.218.51 4.5 1.385A7.962 7.962 0 0114.5 14c1.255 0 2.443.29 3.5.804v-10A7.968 7.968 0 0014.5 4c-1.255 0-2.443.29-3.5.804V12a1 1 0 11-2 0V4.804z" />
                </svg>
                API Docs
              </a>
              <button
                type="button"
                phx-click="open_modal"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                <svg class="-ml-1 mr-2 h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
                </svg>
                Create New Key
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Filter section -->
      <div class="mt-6 bg-white dark:bg-gray-800 shadow sm:rounded-lg">
        <div class="px-4 py-3 sm:px-6">
          <div class="sm:flex sm:items-center sm:justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex">
                <div class="relative flex-1 max-w-xs">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <svg class="h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <input
                    type="text"
                    value={@filter}
                    phx-keyup="filter"
                    phx-debounce="300"
                    class="block w-full pl-10 pr-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md leading-5 bg-white dark:bg-gray-700 placeholder-gray-500 dark:placeholder-gray-400 text-gray-900 dark:text-white focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                    placeholder="Filter by name..."
                  />
                </div>
              </div>
            </div>
            <div class="mt-3 sm:mt-0 sm:ml-4">
              <span class="text-sm text-gray-700 dark:text-gray-300">
                Showing <span class="font-medium"><%= length(@filtered_keys) %></span> API keys
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- API Keys Table -->
      <div class="mt-6 bg-white dark:bg-gray-800 shadow overflow-hidden sm:rounded-lg">
        <%= if @filtered_keys == [] do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-white">No API keys</h3>
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
              <%= if @filter != "" do %>
                No keys match your filter.
              <% else %>
                Get started by creating a new API key.
              <% end %>
            </p>
          </div>
        <% else %>
          <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Name
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Key Preview
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Created
                </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Last Used
                </th>
                <th scope="col" class="relative px-6 py-3">
                  <span class="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              <%= for key <- @filtered_keys do %>
                <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900 dark:text-white"><%= key.name %></div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <code class="text-sm text-gray-500 dark:text-gray-400 font-mono">gopr_****_<%= String.slice(to_string(key.id), -4..-1) %></code>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    <%= format_date(key.inserted_at) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <%= if key.last_used_at do %>
                      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{last_used_class(key.last_used_at)}"}>
                        <%= format_last_used(key.last_used_at) %>
                      </span>
                    <% else %>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400">
                        Never used
                      </span>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div class="flex items-center justify-end gap-3">
                      <button
                        phx-click="open_in_docs"
                        phx-value-id={key.id}
                        title="Open API docs with this key"
                        class="text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300"
                      >
                        <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                          <path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z" />
                          <path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z" />
                        </svg>
                      </button>
                      <button
                        phx-click="revoke"
                        phx-value-id={key.id}
                        data-confirm="Are you sure you want to revoke this API key? This action cannot be undone."
                        class="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-300"
                      >
                        Revoke
                      </button>
                    </div>
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
      <div class="relative z-10" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="fixed inset-0 transition-opacity" phx-click="close_modal"></div>
        <div class="fixed inset-0 z-10 overflow-y-auto">
          <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
            <div class="relative transform overflow-hidden rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
              <.form for={%{}} phx-submit="create_key">
                <div class="bg-white dark:bg-gray-800 px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
                  <div class="sm:flex sm:items-start">
                    <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-indigo-100 dark:bg-indigo-900/30 sm:mx-0 sm:h-10 sm:w-10">
                      <svg class="h-6 w-6 text-indigo-600 dark:text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
                      </svg>
                    </div>
                    <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left flex-1">
                      <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white" id="modal-title">
                        Create New API Key
                      </h3>
                      <div class="mt-4">
                        <label for="key_name" class="block text-sm font-medium leading-6 text-gray-900 dark:text-gray-300">
                          Key Name
                        </label>
                        <input
                          type="text"
                          name="key_name"
                          id="key_name"
                          required
                          class="mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 dark:text-white dark:bg-gray-700 shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
                          placeholder="e.g., Production App"
                        />
                        <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
                          Choose a descriptive name to help you identify this key later.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="bg-gray-50 dark:bg-gray-900 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
                  <button
                    type="submit"
                    class="inline-flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 sm:ml-3 sm:w-auto"
                  >
                    Generate Key
                  </button>
                  <button
                    type="button"
                    phx-click="close_modal"
                    class="mt-3 inline-flex w-full justify-center rounded-md bg-white dark:bg-gray-800 px-3 py-2 text-sm font-semibold text-gray-900 dark:text-gray-300 shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 sm:mt-0 sm:ml-3 sm:w-auto"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <!-- Success Modal with Generated Token -->
    <%= if @generated_token do %>
      <div class="relative z-10" aria-labelledby="success-modal-title" role="dialog" aria-modal="true">
        <div class="fixed inset-0 transition-opacity"></div>
        <div class="fixed inset-0 z-10 overflow-y-auto">
          <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
            <div class="relative transform overflow-hidden rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-2xl">
              <div class="bg-white dark:bg-gray-800 px-4 pb-4 pt-5 sm:p-6">
                <div class="sm:flex sm:items-start">
                  <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-green-100 dark:bg-green-900/30 sm:mx-0 sm:h-10 sm:w-10">
                    <svg class="h-6 w-6 text-green-600 dark:text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left flex-1">
                    <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white" id="success-modal-title">
                      API Key Created Successfully
                    </h3>
                    <div class="mt-4">
                      <div class="rounded-md bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 p-4 mb-4">
                        <div class="flex">
                          <div class="flex-shrink-0">
                            <svg class="h-5 w-5 text-amber-400" viewBox="0 0 20 20" fill="currentColor">
                              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                            </svg>
                          </div>
                          <div class="ml-3">
                            <p class="text-sm text-amber-800 dark:text-amber-200">
                              Make sure to copy your new API key now. You won't be able to see it again!
                            </p>
                          </div>
                        </div>
                      </div>
                      <div class="space-y-3">
                        <div>
                          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                            Your new API key:
                          </label>
                          <div class="flex items-center space-x-2">
                            <code 
                              id="generated-key" 
                              class="flex-1 px-3 py-2 bg-gray-50 dark:bg-gray-900 border border-gray-300 dark:border-gray-600 rounded text-sm font-mono text-gray-900 dark:text-gray-100 select-all break-all"
                            >
                              <%= @generated_token %>
                            </code>
                            <button
                              type="button"
                              id="copy-button"
                              phx-hook="CopyButton"
                              data-clipboard-text={@generated_token}
                              class="inline-flex items-center px-3 py-2 border border-gray-300 dark:border-gray-600 text-sm leading-4 font-medium rounded-md text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                            >
                              <svg class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                              </svg>
                              Copy
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div class="bg-gray-50 dark:bg-gray-900 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
                <button
                  type="button"
                  phx-click="close_success"
                  class="inline-flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 sm:ml-3 sm:w-auto"
                >
                  Done
                </button>
                <a
                  href="/api/docs"
                  target="_blank"
                  class="mt-3 inline-flex w-full justify-center rounded-md bg-white dark:bg-gray-800 px-3 py-2 text-sm font-semibold text-gray-900 dark:text-gray-300 shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 sm:mt-0 sm:w-auto"
                >
                  <svg class="-ml-0.5 mr-2 h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                    <path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z" />
                    <path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z" />
                  </svg>
                  Open API Docs
                </a>
              </div>
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
     |> assign(:filtered_keys, filter_keys(api_keys, socket.assigns.filter))
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
     |> assign(:filtered_keys, filter_keys(api_keys, socket.assigns.filter))
     |> put_flash(:info, "API key revoked successfully.")}
  end

  def handle_event("filter", %{"value" => filter}, socket) do
    filtered_keys = filter_keys(socket.assigns.api_keys, filter)
    
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:filtered_keys, filtered_keys)}
  end
  
  def handle_event("open_in_docs", %{"id" => _id}, socket) do
    # Since we don't store the actual token after creation, we'll inform the user
    {:noreply,
     socket
     |> put_flash(:info, "Please copy your API key first, then paste it in the API docs 'Authorize' dialog.")
     |> push_event("open-url", %{url: "/api/docs"})}
  end

  defp filter_keys(keys, ""), do: keys
  defp filter_keys(keys, filter) do
    filter = String.downcase(filter)
    Enum.filter(keys, fn key ->
      String.contains?(String.downcase(key.name), filter)
    end)
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

  defp last_used_class(nil), do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
  defp last_used_class(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
    
    cond do
      diff < 86400 -> "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
      diff < 604800 -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
      true -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    end
  end
end