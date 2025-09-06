defmodule GoprintRegistryWeb.UserLive.Settings do
  use GoprintRegistryWeb, :live_view

  alias GoprintRegistry.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="bg-white dark:bg-gray-800 shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white">
            Account Settings
          </h3>
          <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
            Manage your account email address and password settings
          </p>
        </div>
      </div>

      <div class="mt-6 bg-white dark:bg-gray-800 shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white">
            Change Email
          </h3>
          <div class="mt-2 max-w-xl text-sm text-gray-500 dark:text-gray-400">
            <p>Update the email address associated with your account.</p>
          </div>
          <.form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
            class="mt-5 sm:flex sm:items-center"
          >
            <div class="w-full sm:max-w-xs">
              <label for="email" class="sr-only">Email</label>
              <input
                type="email"
                name={@email_form[:email].name}
                value={@email_form[:email].value}
                id="email"
                class="block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                placeholder="you@example.com"
                required
              />
              <.error :for={msg <- Enum.map(@email_form[:email].errors || [], &elem(&1, 0))}>
                {msg}
              </.error>
            </div>
            <button
              type="submit"
              phx-disable-with="Changing..."
              class="mt-3 inline-flex w-full items-center justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 sm:ml-3 sm:mt-0 sm:w-auto"
            >
              Change Email
            </button>
          </.form>
        </div>
      </div>

      <div class="mt-6 bg-white dark:bg-gray-800 shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-white">
            Change Password
          </h3>
          <div class="mt-2 max-w-xl text-sm text-gray-500 dark:text-gray-400">
            <p>Ensure your account is using a long, random password to stay secure.</p>
          </div>
          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
            class="mt-5 space-y-4"
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              autocomplete="username"
              value={@current_email}
            />
            <div>
              <label
                for="password"
                class="block text-sm font-medium text-gray-700 dark:text-gray-300"
              >
                New password
              </label>
              <div class="mt-1">
                <input
                  type="password"
                  name={@password_form[:password].name}
                  value={@password_form[:password].value}
                  id="password"
                  autocomplete="new-password"
                  required
                  class="block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
                <.error :for={msg <- Enum.map(@password_form[:password].errors || [], &elem(&1, 0))}>
                  {msg}
                </.error>
              </div>
            </div>
            <div>
              <label
                for="password_confirmation"
                class="block text-sm font-medium text-gray-700 dark:text-gray-300"
              >
                Confirm new password
              </label>
              <div class="mt-1">
                <input
                  type="password"
                  name={@password_form[:password_confirmation].name}
                  value={@password_form[:password_confirmation].value}
                  id="password_confirmation"
                  autocomplete="new-password"
                  class="block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
                <.error
                  :for={msg <- Enum.map(@password_form[:password_confirmation].errors || [], &elem(&1, 0))}
                >
                  {msg}
                </.error>
              </div>
            </div>
            <div>
              <button
                type="submit"
                phx-disable-with="Saving..."
                class="inline-flex justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                Update Password
              </button>
            </div>
          </.form>
        </div>
      </div>

      <div class="mt-6 bg-white dark:bg-gray-800 shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-base font-semibold leading-6 text-red-600 dark:text-red-400">
            Danger Zone
          </h3>
          <div class="mt-2 max-w-xl text-sm text-gray-500 dark:text-gray-400">
            <p>Once you delete your account, there is no going back. Please be certain.</p>
          </div>
          <div class="mt-5">
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-500"
            >
              Delete Account
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket, layout: {GoprintRegistryWeb.Layouts, :app}}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        # For now, just update the email directly without confirmation
        case Accounts.update_user_email_direct(user, user_params["email"]) do
          {:ok, _updated_user} ->
            {:noreply,
             socket
             |> put_flash(:info, "Email updated successfully.")
             |> push_navigate(to: ~p"/users/settings")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Unable to update email.")}
        end

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.update_user_password(user, user_params["password"]) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params, hash_password: false)
          |> to_form()

        {:noreply,
         socket
         |> assign(:password_form, password_form)
         |> put_flash(:info, "Password updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_form, to_form(changeset, action: :insert))}
    end
  end
end