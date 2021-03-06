defmodule Openstex.Adapters.Ovh.Keystone do
  @moduledoc :false
  alias Openstex.Adapters.Ovh.Keystone.Utils
  import Openstex.Utils, only: [ets_tablename: 1]
  @behaviour Openstex.Adapter.Keystone
  @get_identity_retries 5
  @get_identity_interval 1000
  @update_identity_buffer (10 * 1000)


  # Public Openstex.Adapter.Keystone callbacks

  def start_link(openstex_client) do
    GenServer.start_link(__MODULE__, openstex_client, [name: openstex_client])
  end

  def start_link(openstex_client, _opts) do
    start_link(openstex_client)
  end

  def identity(openstex_client) do
    get_identity(openstex_client)
  end

  def get_xauth_token(openstex_client) do
    get_identity(openstex_client) |> Map.get(:token) |> Map.get(:id)
  end

  # Genserver Callbacks

  def init(openstex_client) do
    :erlang.process_flag(:trap_exit, :true)
    create_ets_table(openstex_client)
    identity = Utils.create_identity(openstex_client)
    :ets.insert(ets_tablename(openstex_client), {:identity, identity})
    milliseconds_to_expiry = (get_seconds_to_expiry(identity) * 1000) - @update_identity_buffer
    timer_ref = Process.send_after(self(), :update_identity, milliseconds_to_expiry)
    {:ok, {openstex_client, identity, timer_ref}}
  end

  def handle_call(:update_identity, _from, {openstex_client, identity, timer_ref}) do
    {:reply, :ok, update_identity({openstex_client, identity, timer_ref})}
  end
  def handle_info(:update_identity, {openstex_client, identity, timer_ref}) do
    {:noreply, update_identity({openstex_client, identity, timer_ref})}
  end
  def handle_info(_info, {openstex_client, identity, timer_ref}) do
    {:noreply, {openstex_client, identity, timer_ref}}
  end
  def terminate(_reason, {openstex_client, _identity, _timer_ref}) do
    :ets.delete(ets_tablename(openstex_client))
    :ok
  end


  # private


  defp get_identity(openstex_client) do
    unless genserver_exists?(openstex_client), do: start_link(openstex_client)
    get_identity(openstex_client, 0)
  end
  defp get_identity(openstex_client, index) do
    retry = fn(openstex_client, index) ->
      if index > @get_identity_retries do
        raise "Cannot retrieve openstack identity, #{__ENV__.module}, #{__ENV__.line}, client: #{openstex_client}"
      else
        :timer.sleep(@get_identity_interval)
        get_identity(openstex_client, index + 1)
      end
    end

    if ets_tablename(openstex_client) in :ets.all() do
      table = :ets.lookup(ets_tablename(openstex_client), :identity)
      case table do
        [identity: identity] ->
          identity
        [] -> retry.(openstex_client, index)
      end
    else
      retry.(openstex_client, index)
    end
  end


  defp update_identity({openstex_client, _identity, timer_ref}) do
    new_identity = Utils.create_identity(openstex_client)
    :ets.insert(ets_tablename(openstex_client), {:identity, new_identity})
    milliseconds_to_expiry = (get_seconds_to_expiry(new_identity) * 1000) - @update_identity_buffer
    :timer.cancel(timer_ref)
    timer_ref = Process.send_after(self(), :update_identity, milliseconds_to_expiry)
    {openstex_client, new_identity, timer_ref}
  end


  defp get_seconds_to_expiry(identity) do
    iso_time = identity.token.expires
    (
    DateTime.from_iso8601(iso_time)
    |> Tuple.to_list()
    |> Enum.at(1)
    |> DateTime.to_unix()
    ) -
    (DateTime.utc_now() |> DateTime.to_unix())
  end


  defp create_ets_table(openstex_client) do
    ets_options = [
                   :set, # type
                   :protected, # read - all, write this process only.
                   :named_table,
                   {:heir, :none}, # don't let any process inherit the table. when the ets table dies, it dies.
                   {:write_concurrency, :false},
                   {:read_concurrency, :true}
                  ]
    unless ets_tablename(openstex_client) in :ets.all() do
      :ets.new(ets_tablename(openstex_client), ets_options)
    end
  end


  defp genserver_exists?(client) do
    Process.whereis(client) != :nil
  end


end
