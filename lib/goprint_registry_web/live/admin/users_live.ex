defmodule GoprintRegistryWeb.Admin.UsersLive do
  use GoprintRegistryWeb, :live_view
  alias GoprintRegistry.Accounts
  alias GoprintRegistry.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin - Users")
     |> assign(:show_modal, false)
     |> assign(:edit_user, nil)
     |> assign(:form, nil)
     |> stream(:users, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case Flop.validate(params, for: User) do
      {:ok, flop} ->
        {users, meta} = Accounts.list_users_with_flop(flop)
        
        {:noreply,
         socket
         |> stream(:users, users, reset: true)
         |> assign(:meta, meta)}
      
      {:error, _meta} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/users")}
    end
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")
    {:noreply, push_patch(socket, to: ~p"/admin/users?#{params}")}
  end

  @impl true
  def handle_event("edit-user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    changeset = Accounts.change_user_admin(user)
    
    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:edit_user, user)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("close-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:edit_user, nil)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.edit_user
      |> Accounts.change_user_admin(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_admin(socket.assigns.edit_user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> assign(:show_modal, false)
         |> assign(:edit_user, nil)
         |> assign(:form, nil)
         |> push_navigate(to: ~p"/admin/users")}
      
      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-3xl font-bold leading-6 text-gray-900">Users</h1>
          <p class="mt-2 text-sm text-gray-700">
            Manage all registered users in the system.
          </p>
        </div>
      </div>

      <!-- Search and Filters -->
      <div class="mt-6">
        <.form :let={_f} for={%{}} phx-change="update-filter" phx-submit="update-filter">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div>
              <label for="search" class="block text-sm font-medium text-gray-700">Search</label>
              <div class="mt-1">
                <input
                  type="text"
                  name="q"
                  id="search"
                  value={@meta.flop.filters[:q] || ""}
                  placeholder="Search by email..."
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                />
              </div>
            </div>
            
            <div>
              <label for="admin_filter" class="block text-sm font-medium text-gray-700">Admin Status</label>
              <div class="mt-1">
                <select
                  name="is_admin"
                  id="admin_filter"
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                >
                  <option value="">All Users</option>
                  <option value="true" selected={@meta.flop.filters[:is_admin] == "true"}>Admins Only</option>
                  <option value="false" selected={@meta.flop.filters[:is_admin] == "false"}>Non-Admins Only</option>
                </select>
              </div>
            </div>
          </div>
        </.form>
      </div>

      <!-- Users Table -->
      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                      Email
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Status
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Admin
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Confirmed
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Registered
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <tr :for={{id, user} <- @streams.users} id={id}>
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                      <%= user.email %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <span :if={user.confirmed_at} class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                        Active
                      </span>
                      <span :if={!user.confirmed_at} class="inline-flex items-center rounded-full bg-yellow-100 px-2.5 py-0.5 text-xs font-medium text-yellow-800">
                        Unconfirmed
                      </span>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <span :if={user.is_admin} class="inline-flex items-center rounded-full bg-purple-100 px-2.5 py-0.5 text-xs font-medium text-purple-800">
                        Admin
                      </span>
                      <span :if={!user.is_admin} class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800">
                        User
                      </span>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= if user.confirmed_at do %>
                        <%= Calendar.strftime(user.confirmed_at, "%b %d, %Y") %>
                      <% else %>
                        -
                      <% end %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= Calendar.strftime(user.inserted_at, "%b %d, %Y") %>
                    </td>
                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                      <button
                        phx-click="edit-user"
                        phx-value-id={user.id}
                        class="text-blue-600 hover:text-blue-900"
                      >
                        Edit
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <!-- Pagination -->
      <div class="mt-4">
        <Flop.Phoenix.pagination meta={@meta} path={~p"/admin/users"} />
      </div>

      <!-- Edit Modal -->
      <%= if @show_modal do %>
        <div class="relative z-50" aria-labelledby="modal-title" role="dialog" aria-modal="true">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
          <div class="fixed inset-0 z-10 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
                <div class="bg-white px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
                  <div class="sm:flex sm:items-start">
                    <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left w-full">
                      <h3 class="text-base font-semibold leading-6 text-gray-900" id="modal-title">
                        Edit User
                      </h3>
                      <div class="mt-4">
                        <.form :let={f} for={@form} phx-change="validate" phx-submit="save">
                          <div class="space-y-4">
                            <div>
                              <label for="email" class="block text-sm font-medium text-gray-700">
                                Email
                              </label>
                              <input
                                type="email"
                                name={f[:email].name}
                                id="email"
                                value={@edit_user.email}
                                disabled
                                class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm sm:text-sm"
                              />
                            </div>

                            <div>
                              <label for="is_admin" class="block text-sm font-medium text-gray-700">
                                Admin Role
                              </label>
                              <select
                                name={f[:is_admin].name}
                                id="is_admin"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                              >
                                <option value="false" selected={!@edit_user.is_admin}>Regular User</option>
                                <option value="true" selected={@edit_user.is_admin}>Administrator</option>
                              </select>
                              <p class="mt-1 text-sm text-gray-500">
                                Administrators have full access to manage users and system settings.
                              </p>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700">
                                Account Status
                              </label>
                              <div class="mt-1">
                                <%= if @edit_user.confirmed_at do %>
                                  <span class="inline-flex items-center rounded-full bg-green-100 px-3 py-1 text-sm font-medium text-green-800">
                                    Confirmed
                                  </span>
                                <% else %>
                                  <span class="inline-flex items-center rounded-full bg-yellow-100 px-3 py-1 text-sm font-medium text-yellow-800">
                                    Unconfirmed
                                  </span>
                                <% end %>
                              </div>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700">
                                Registered
                              </label>
                              <p class="mt-1 text-sm text-gray-900">
                                <%= Calendar.strftime(@edit_user.inserted_at, "%B %d, %Y at %I:%M %p") %>
                              </p>
                            </div>
                          </div>

                          <div class="mt-5 sm:mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                            <button
                              type="submit"
                              class="inline-flex w-full justify-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600 sm:col-start-2"
                            >
                              Save Changes
                            </button>
                            <button
                              type="button"
                              phx-click="close-modal"
                              class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:col-start-1 sm:mt-0"
                            >
                              Cancel
                            </button>
                          </div>
                        </.form>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end