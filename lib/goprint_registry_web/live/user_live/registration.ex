defmodule GoprintRegistryWeb.UserLive.Registration do
  use GoprintRegistryWeb, :live_view

  alias GoprintRegistry.Accounts
  alias GoprintRegistry.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-full flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <img src="/images/go-logo.png" alt="GoPrint" class="mx-auto h-10 w-auto" />
        <h2 class="mt-6 text-center text-2xl/9 font-bold tracking-tight text-gray-900 dark:text-white">
          Create your account
        </h2>
      </div>

      <div class="mt-10 sm:mx-auto sm:w-full sm:max-w-[480px]">
        <div class="bg-white px-6 py-12 shadow sm:rounded-lg sm:px-12 dark:bg-gray-800/50 dark:shadow-none dark:outline dark:outline-1 dark:-outline-offset-1 dark:outline-white/10">
          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            class="space-y-6"
          >
            <div>
              <label for="email" class="block text-sm/6 font-medium text-gray-900 dark:text-white">
                Email address
              </label>
              <div class="mt-2">
                <input
                  id="email"
                  type="email"
                  name={@form[:email].name}
                  value={@form[:email].value}
                  required
                  autocomplete="email"
                  phx-mounted={JS.focus()}
                  class="block w-full rounded-md bg-white px-3 py-1.5 text-base text-gray-900 outline outline-1 -outline-offset-1 outline-gray-300 placeholder:text-gray-400 focus:outline focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600 sm:text-sm/6 dark:bg-white/5 dark:text-white dark:outline-white/10 dark:placeholder:text-gray-500 dark:focus:outline-indigo-500"
                />
                <.error :for={msg <- Enum.map(@form[:email].errors || [], &elem(&1, 0))}>
                  {msg}
                </.error>
              </div>
            </div>

            <div>
              <label for="password" class="block text-sm/6 font-medium text-gray-900 dark:text-white">
                Password
              </label>
              <div class="mt-2">
                <input
                  id="password"
                  type="password"
                  name={@form[:password].name}
                  value={@form[:password].value}
                  required
                  autocomplete="new-password"
                  placeholder="At least 10 characters"
                  class="block w-full rounded-md bg-white px-3 py-1.5 text-base text-gray-900 outline outline-1 -outline-offset-1 outline-gray-300 placeholder:text-gray-400 focus:outline focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600 sm:text-sm/6 dark:bg-white/5 dark:text-white dark:outline-white/10 dark:placeholder:text-gray-500 dark:focus:outline-indigo-500"
                />
                <.error :for={msg <- Enum.map(@form[:password].errors || [], &elem(&1, 0))}>
                  {msg}
                </.error>
              </div>
            </div>

            <div>
              <label for="password_confirmation" class="block text-sm/6 font-medium text-gray-900 dark:text-white">
                Confirm Password
              </label>
              <div class="mt-2">
                <input
                  id="password_confirmation"
                  type="password"
                  name={@form[:password_confirmation].name}
                  value={@form[:password_confirmation].value}
                  required
                  autocomplete="new-password"
                  placeholder="Confirm your password"
                  class="block w-full rounded-md bg-white px-3 py-1.5 text-base text-gray-900 outline outline-1 -outline-offset-1 outline-gray-300 placeholder:text-gray-400 focus:outline focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600 sm:text-sm/6 dark:bg-white/5 dark:text-white dark:outline-white/10 dark:placeholder:text-gray-500 dark:focus:outline-indigo-500"
                />
                <.error :for={msg <- Enum.map(@form[:password_confirmation].errors || [], &elem(&1, 0))}>
                  {msg}
                </.error>
              </div>
            </div>

            <div>
              <button
                type="submit"
                phx-disable-with="Creating account..."
                class="flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm/6 font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 dark:bg-indigo-500 dark:shadow-none dark:hover:bg-indigo-400 dark:focus-visible:outline-indigo-500"
              >
                Create account
              </button>
            </div>
          </.form>

          <div :if={false}>
            <div class="mt-10 flex items-center gap-x-6">
              <div class="w-full flex-1 border-t border-gray-200 dark:border-white/10"></div>
              <p class="text-nowrap text-sm/6 font-medium text-gray-900 dark:text-white">
                Or continue with
              </p>
              <div class="w-full flex-1 border-t border-gray-200 dark:border-white/10"></div>
            </div>

            <div class="mt-6 grid grid-cols-2 gap-4">
              <a
                href="#"
                class="flex w-full items-center justify-center gap-3 rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus-visible:ring-transparent dark:bg-white/10 dark:text-white dark:shadow-none dark:ring-white/5 dark:hover:bg-white/20"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true" class="h-5 w-5">
                  <path
                    d="M12.0003 4.75C13.7703 4.75 15.3553 5.36002 16.6053 6.54998L20.0303 3.125C17.9502 1.19 15.2353 0 12.0003 0C7.31028 0 3.25527 2.69 1.28027 6.60998L5.27028 9.70498C6.21525 6.86002 8.87028 4.75 12.0003 4.75Z"
                    fill="#EA4335"
                  />
                  <path
                    d="M23.49 12.275C23.49 11.49 23.415 10.73 23.3 10H12V14.51H18.47C18.18 15.99 17.34 17.25 16.08 18.1L19.945 21.1C22.2 19.01 23.49 15.92 23.49 12.275Z"
                    fill="#4285F4"
                  />
                  <path
                    d="M5.26498 14.2949C5.02498 13.5699 4.88501 12.7999 4.88501 11.9999C4.88501 11.1999 5.01998 10.4299 5.26498 9.7049L1.275 6.60986C0.46 8.22986 0 10.0599 0 11.9999C0 13.9399 0.46 15.7699 1.28 17.3899L5.26498 14.2949Z"
                    fill="#FBBC05"
                  />
                  <path
                    d="M12.0004 24.0001C15.2404 24.0001 17.9654 22.935 19.9454 21.095L16.0804 18.095C15.0054 18.82 13.6204 19.245 12.0004 19.245C8.8704 19.245 6.21537 17.135 5.2654 14.29L1.27539 17.385C3.25539 21.31 7.3104 24.0001 12.0004 24.0001Z"
                    fill="#34A853"
                  />
                </svg>
                <span class="text-sm/6 font-semibold">Google</span>
              </a>

              <a
                href="#"
                class="flex w-full items-center justify-center gap-3 rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus-visible:ring-transparent dark:bg-white/10 dark:text-white dark:shadow-none dark:ring-white/5 dark:hover:bg-white/20"
              >
                <svg
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                  class="size-5 fill-[#24292F] dark:fill-white"
                >
                  <path
                    d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z"
                    clip-rule="evenodd"
                    fill-rule="evenodd"
                  />
                </svg>
                <span class="text-sm/6 font-semibold">GitHub</span>
              </a>
            </div>
          </div>
        </div>

        <p class="mt-10 text-center text-sm/6 text-gray-500 dark:text-gray-400">
          Already have an account?
          <.link
            navigate={~p"/users/log-in"}
            class="font-semibold text-indigo-600 hover:text-indigo-500 dark:text-indigo-400 dark:hover:text-indigo-300"
          >
            Sign in
          </.link>
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: GoprintRegistryWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(:page_title, "Create account")
      |> assign(:current_user, nil)

    {:ok, assign_form(socket, changeset),
     temporary_assigns: [form: nil], layout: {GoprintRegistryWeb.Layouts, :landing}}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        # For now, skip email confirmation
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Account created successfully! Please sign in."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form, check_errors: true)
    end
  end
end