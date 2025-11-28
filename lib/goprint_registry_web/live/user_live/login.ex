defmodule GoprintRegistryWeb.UserLive.Login do
  use GoprintRegistryWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-full flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 class="text-center text-2xl/9 font-bold tracking-tight text-foreground">
          Sign in to your account
        </h2>
      </div>

      <div class="mt-10 sm:mx-auto sm:w-full sm:max-w-[480px]">
        <div class="bg-card px-6 py-12 shadow sm:rounded-lg sm:px-12 border border-base">
          <.form
            for={@form}
            id="login_form"
            action={~p"/users/log-in"}
            phx-submit="submit"
            phx-trigger-action={@trigger_submit}
            class="space-y-6"
          >
            <.input
              field={@form[:email]}
              type="email"
              label="Email address"
              required
              autocomplete="email"
              phx-mounted={JS.focus()}
            />

            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              required
              autocomplete="current-password"
            />

            <.checkbox field={@form[:remember_me]} label="Remember me" />

            <.button type="submit" variant="solid" color="primary" class="w-full" phx-disable-with="Signing in...">
              Sign in
            </.button>
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

          <div :if={local_mail_adapter?()} class="mt-6 rounded-lg bg-blue-50 dark:bg-blue-900/20 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400" />
              </div>
              <div class="ml-3 flex-1 md:flex md:justify-between">
                <p class="text-sm text-blue-700 dark:text-blue-300">
                  Development mode: Visit
                  <.link href="/dev/mailbox" class="font-medium underline">
                    the mailbox
                  </.link>
                  to see sent emails.
                </p>
              </div>
            </div>
          </div>
        </div>

        <p class="mt-10 text-center text-sm/6 text-muted-foreground">
          Not a member?
          <.link
            navigate={~p"/users/register"}
            class="font-semibold text-primary hover:text-primary/80"
          >
            Create an account
          </.link>
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    socket =
      socket
      |> assign(:page_title, "Sign in")
      |> assign(:current_user, nil)
      |> assign(:form, form)
      |> assign(:trigger_submit, false)

    {:ok, socket, layout: {GoprintRegistryWeb.Layouts, :landing}}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  defp local_mail_adapter? do
    Application.get_env(:goprint_registry, GoprintRegistry.Mailer)[:adapter] ==
      Swoosh.Adapters.Local
  end
end