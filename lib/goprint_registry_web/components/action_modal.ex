defmodule GoprintRegistryWeb.Components.Core.ActionModal do
  @moduledoc """
  Reusable action modal component with FlowBite styling.

  This modal component can be used for edit, view, and confirmation actions.
  It supports different sizes and custom content rendering.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal dialog with FlowBite styling.

  ## Examples

      <.action_modal id="edit-modal" show={@show_modal}>
        <:title>Edit Product</:title>
        <:body>
          <!-- Form or content here -->
        </:body>
        <:footer>
          <button type="submit">Save</button>
        </:footer>
      </.action_modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :size, :string, default: "default", values: ["small", "default", "large", "xl", "full"]
  attr :on_cancel, JS, default: %JS{}
  attr :class, :string, default: ""

  slot :title, required: true
  slot :body, required: true
  slot :footer

  def action_modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-modal={@show}
      class={["fixed inset-0 z-50 overflow-y-auto", (@show && "flex") || "hidden"]}
      aria-labelledby={"#{@id}-title"}
      aria-hidden={!@show}
      role="dialog"
      aria-modal="true"
    >
      <!-- Backdrop -->
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-gray-900 bg-opacity-50 dark:bg-opacity-80"
        aria-hidden="true"
        phx-click={JS.exec(@on_cancel, "phx-remove", to: "##{@id}")}
      >
      </div>
      
    <!-- Modal Content -->
      <div class={[
        "relative flex items-center justify-center min-h-screen w-full p-4",
        modal_size_class(@size)
      ]}>
        <div
          id={"#{@id}-container"}
          class={[
            "relative bg-white rounded-lg shadow-xl dark:bg-gray-700",
            "transform transition-all",
            @class
          ]}
          phx-click-away={JS.exec(@on_cancel, "phx-remove", to: "##{@id}")}
          phx-window-keydown={JS.exec(@on_cancel, "phx-remove", to: "##{@id}")}
          phx-key="escape"
        >
          <!-- Modal Header -->
          <div class="flex items-start justify-between p-4 border-b rounded-t dark:border-gray-600">
            <h3
              id={"#{@id}-title"}
              class="text-xl font-semibold text-gray-900 dark:text-white"
            >
              {render_slot(@title)}
            </h3>
            <button
              type="button"
              class="text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm p-1.5 ml-auto inline-flex items-center dark:hover:bg-gray-600 dark:hover:text-white"
              phx-click={JS.exec(@on_cancel, "phx-remove", to: "##{@id}")}
              aria-label="Close modal"
            >
              <svg
                class="w-5 h-5"
                fill="currentColor"
                viewBox="0 0 20 20"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  fill-rule="evenodd"
                  d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                  clip-rule="evenodd"
                >
                </path>
              </svg>
            </button>
          </div>
          
    <!-- Modal Body -->
          <div class="p-6 space-y-6 max-h-[60vh] overflow-y-auto">
            {render_slot(@body)}
          </div>
          
    <!-- Modal Footer -->
          <%= if @footer != [] do %>
            <div class="flex items-center p-6 space-x-2 border-t border-gray-200 rounded-b dark:border-gray-600">
              {render_slot(@footer)}
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Confirmation modal for delete and other destructive actions.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, default: "Confirm Action"
  attr :message, :string, required: true
  attr :confirm_text, :string, default: "Confirm"
  attr :cancel_text, :string, default: "Cancel"

  attr :confirm_class, :string,
    default: "bg-red-600 hover:bg-red-700 focus:ring-red-300 dark:focus:ring-red-800"

  attr :on_confirm, JS, required: true
  attr :on_cancel, JS, default: %JS{}

  def confirmation_modal(assigns) do
    ~H"""
    <.action_modal id={@id} show={@show} size="small" on_cancel={@on_cancel}>
      <:title>
        <div class="flex items-center">
          <svg
            class="w-6 h-6 mr-2 text-red-600 dark:text-red-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            >
            </path>
          </svg>
          {@title}
        </div>
      </:title>
      <:body>
        <p class="text-base leading-relaxed text-gray-500 dark:text-gray-400">
          {@message}
        </p>
      </:body>
      <:footer>
        <button
          type="button"
          phx-click={@on_confirm}
          class={[
            "text-white font-medium rounded-lg text-sm px-5 py-2.5 text-center",
            @confirm_class
          ]}
        >
          {@confirm_text}
        </button>
        <button
          type="button"
          phx-click={JS.exec(@on_cancel, "phx-remove", to: "##{@id}")}
          class="text-gray-500 bg-white hover:bg-gray-100 focus:ring-4 focus:outline-none focus:ring-gray-200 rounded-lg border border-gray-200 text-sm font-medium px-5 py-2.5 hover:text-gray-900 focus:z-10 dark:bg-gray-700 dark:text-gray-300 dark:border-gray-500 dark:hover:text-white dark:hover:bg-gray-600 dark:focus:ring-gray-600"
        >
          {@cancel_text}
        </button>
      </:footer>
    </.action_modal>
    """
  end

  @doc """
  Form modal for edit and create actions.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, required: true
  attr :form, :any, required: true
  attr :action, :string, required: true
  attr :size, :string, default: "default"
  attr :on_cancel, JS, default: %JS{}
  attr :save_text, :string, default: "Save"
  attr :saving_text, :string, default: "Saving..."

  slot :fields, required: true
  slot :extra_footer

  def form_modal(assigns) do
    ~H"""
    <.action_modal id={@id} show={@show} size={@size} on_cancel={@on_cancel}>
      <:title>{@title}</:title>
      <:body>
        <.form
          for={@form}
          id={"#{@id}-form"}
          phx-submit={@action}
          class="space-y-4"
        >
          {render_slot(@fields, @form)}
        </.form>
      </:body>
      <:footer>
        <button
          type="submit"
          form={"#{@id}-form"}
          phx-disable-with={@saving_text}
          class="text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800"
        >
          {@save_text}
        </button>
        {render_slot(@extra_footer)}
        <button
          type="button"
          phx-click={JS.exec(@on_cancel, "phx-remove", to: "##{@id}")}
          class="text-gray-500 bg-white hover:bg-gray-100 focus:ring-4 focus:outline-none focus:ring-gray-200 rounded-lg border border-gray-200 text-sm font-medium px-5 py-2.5 hover:text-gray-900 focus:z-10 dark:bg-gray-700 dark:text-gray-300 dark:border-gray-500 dark:hover:text-white dark:hover:bg-gray-600 dark:focus:ring-gray-600"
        >
          Cancel
        </button>
      </:footer>
    </.action_modal>
    """
  end

  defp modal_size_class("small"), do: "max-w-md"
  defp modal_size_class("default"), do: "max-w-2xl"
  defp modal_size_class("large"), do: "max-w-4xl"
  defp modal_size_class("xl"), do: "max-w-7xl"
  defp modal_size_class("full"), do: "max-w-full mx-4"

  def show_modal(id, js \\ %JS{}) do
    js
    |> JS.show(to: "##{id}", transition: "fade-in")
    |> JS.show(
      to: "##{id}-container",
      transition:
        {"ease-out duration-300", "opacity-0 translate-y-4", "opacity-100 translate-y-0"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-container")
  end

  def hide_modal(id, js \\ %JS{}) do
    js
    |> JS.hide(
      to: "##{id}-container",
      transition: {"ease-in duration-200", "opacity-100 translate-y-0", "opacity-0 translate-y-4"}
    )
    |> JS.hide(to: "##{id}", transition: "fade-out")
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
