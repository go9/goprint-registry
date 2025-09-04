defmodule GoprintRegistry.Registry do
  use GenServer
  require Logger

  @table_name :goprint_registry
  @cleanup_interval 60_000 # Clean up expired entries every minute
  @ttl 300 # 5 minutes

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    # Create ETS table
    :ets.new(@table_name, [:set, :public, :named_table])
    
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)
    
    Logger.info("GoPrint Registry started")
    {:ok, %{}}
  end

  def handle_info(:cleanup, state) do
    # Remove expired entries
    now = System.system_time(:second)
    expired_keys = :ets.foldl(
      fn {key, _data, timestamp}, acc ->
        if now - timestamp > @ttl do
          [key | acc]
        else
          acc
        end
      end,
      [],
      @table_name
    )
    
    Enum.each(expired_keys, &:ets.delete(@table_name, &1))
    
    if length(expired_keys) > 0 do
      Logger.info("Cleaned up #{length(expired_keys)} expired GoPrint registrations")
    end
    
    # Schedule next cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)
    
    {:noreply, state}
  end
end