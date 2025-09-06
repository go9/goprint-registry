defmodule GoprintRegistry.ClientTracker do
  @moduledoc """
  Tracks connected desktop clients using Phoenix.Presence
  """
  use Phoenix.Presence,
    otp_app: :goprint_registry,
    pubsub_server: GoprintRegistry.PubSub
end