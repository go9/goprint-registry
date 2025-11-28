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
          <h1 class="text-3xl font-bold leading-6 text-foreground">Users</h1>
          <p class="mt-2 text-sm text-muted-foreground">
            Manage all registered users in the system.
          </p>
        </div>
      </div>

      <!-- Search and Filters -->
      <div class="mt-6">
        <.form for={%{}} phx-change="update-filter" phx-submit="update-filter">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <.input
              type="text"
              name="q"
              value={@meta.flop.filters[:q] || ""}
              label="Search"
              placeholder="Search by email..."
            />

            <.select
              name="is_admin"
              label="Admin Status"
              options={[{"All Users", ""}, {"Admins Only", "true"}, {"Non-Admins Only", "false"}]}
              value={@meta.flop.filters[:is_admin] || ""}
            />

            <div class="flex items-end">
              <.button
                :if={@meta.flop.filters[:q] || @meta.flop.filters[:is_admin]}
                type="button"
                variant="ghost"
                phx-click={JS.patch(~p"/admin/users")}
              >
                Clear filters
              </.button>
            </div>
          </div>
        </.form>
      </div>

      <!-- Users Table -->
      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black/5 dark:ring-white/10 sm:rounded-lg">
              <table class="min-w-full divide-y divide-base">
                <thead class="bg-muted/50">
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-foreground sm:pl-6">
                      Email
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-foreground">
                      Status
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-foreground">
                      Admin
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-foreground">
                      Confirmed
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-foreground">
                      Registered
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-base bg-card">
                  <tr :for={{id, user} <- @streams.users} id={id}>
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-foreground sm:pl-6">
                      <%= user.email %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-muted-foreground">
                      <.badge :if={user.confirmed_at} color="success">Active</.badge>
                      <.badge :if={!user.confirmed_at} color="warning">Unconfirmed</.badge>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-muted-foreground">
                      <.badge :if={user.is_admin} color="primary">Admin</.badge>
                      <.badge :if={!user.is_admin} color="info">User</.badge>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-muted-foreground">
                      <%= if user.confirmed_at do %>
                        <%= Calendar.strftime(user.confirmed_at, "%b %d, %Y") %>
                      <% else %>
                        -
                      <% end %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-muted-foreground">
                      <%= Calendar.strftime(user.inserted_at, "%b %d, %Y") %>
                    </td>
                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                      <.button
                        variant="ghost"
                        size="sm"
                        phx-click="edit-user"
                        phx-value-id={user.id}
                      >
                        Edit
                      </.button>
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
          <div class="fixed inset-0 bg-black/50 transition-opacity"></div>
          <div class="fixed inset-0 z-10 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-card border border-base text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
                <div class="bg-card px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
                  <div class="sm:flex sm:items-start">
                    <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left w-full">
                      <h3 class="text-base font-semibold leading-6 text-foreground" id="modal-title">
                        Edit User
                      </h3>
                      <div class="mt-4">
                        <.form for={@form} phx-change="validate" phx-submit="save">
                          <div class="space-y-4">
                            <.input
                              type="email"
                              name="user[email]"
                              label="Email"
                              value={@edit_user.email}
                              disabled
                            />

                            <.select
                              name="user[is_admin]"
                              label="Admin Role"
                              options={[{"Regular User", "false"}, {"Administrator", "true"}]}
                              value={to_string(@edit_user.is_admin)}
                            />
                            <p class="text-sm text-muted-foreground -mt-2">
                              Administrators have full access to manage users and system settings.
                            </p>

                            <div>
                              <label class="block text-sm font-medium text-foreground">
                                Account Status
                              </label>
                              <div class="mt-1">
                                <.badge :if={@edit_user.confirmed_at} color="success">Confirmed</.badge>
                                <.badge :if={!@edit_user.confirmed_at} color="warning">Unconfirmed</.badge>
                              </div>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-foreground">
                                Registered
                              </label>
                              <p class="mt-1 text-sm text-foreground">
                                <%= Calendar.strftime(@edit_user.inserted_at, "%B %d, %Y at %I:%M %p") %>
                              </p>
                            </div>
                          </div>

                          <div class="mt-5 sm:mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                            <.button type="submit" variant="solid" color="primary" class="w-full sm:col-start-2">
                              Save Changes
                            </.button>
                            <.button
                              type="button"
                              variant="outline"
                              phx-click="close-modal"
                              class="mt-3 w-full sm:col-start-1 sm:mt-0"
                            >
                              Cancel
                            </.button>
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