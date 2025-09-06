defmodule GoprintRegistryWeb.Components.Core.TagPill do
  @moduledoc """
  A reusable component for displaying tags as colored pills.
  """
  use Phoenix.Component

  @doc """
  Renders a tag as a colored pill.

  ## Examples

      <.render_tag_pill name="New" color="#FF0000" />
      <.render_tag_pill name="Sale" color="#00FF00" size="sm" />
  """
  attr :name, :string, required: true
  attr :color, :string, default: "#6B7280"
  attr :size, :string, default: "md", values: ["sm", "md", "lg"]
  attr :class, :string, default: ""

  def render_tag_pill(assigns) do
    text_color = calculate_text_color(assigns.color)

    size_classes =
      case assigns.size do
        "sm" -> "px-2 py-0.5 text-xs"
        "lg" -> "px-3 py-1.5 text-sm"
        _ -> "px-2.5 py-1 text-xs"
      end

    assigns =
      assigns
      |> assign(:text_color, text_color)
      |> assign(:size_classes, size_classes)

    ~H"""
    <span
      class={"inline-flex items-center font-medium rounded-full #{@size_classes} #{@class}"}
      style={"background-color: #{@color}; color: #{@text_color};"}
    >
      {@name}
    </span>
    """
  end

  # Calculate whether text should be white or black based on background color
  defp calculate_text_color(nil), do: "#FFFFFF"
  defp calculate_text_color(""), do: "#FFFFFF"

  defp calculate_text_color(hex_color) do
    # Remove # if present
    hex = String.replace(hex_color, "#", "")

    # Convert hex to RGB
    {r, g, b} =
      case String.length(hex) do
        6 ->
          {
            String.slice(hex, 0, 2) |> String.to_integer(16),
            String.slice(hex, 2, 2) |> String.to_integer(16),
            String.slice(hex, 4, 2) |> String.to_integer(16)
          }

        _ ->
          # Default to gray if invalid
          {128, 128, 128}
      end

    # Calculate luminance
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    # Return white text for dark backgrounds, black for light
    if luminance > 0.5, do: "#000000", else: "#FFFFFF"
  end
end
