defmodule Openstex.Adapters.Ovh.Config do
  @moduledoc :false
  @default_headers [{"Content-Type", "application/json; charset=utf-8"}]
  @default_options [timeout: 10000, recv_timeout: 30000]
  @default_adapter HTTPipe.Adapters.Hackney
  @default_ovh_region "SBG1"
  alias Openstex.Keystone.V2.Helpers.Identity
  alias Openstex.Adapters.Ovh.Keystone.Utils
  use Openstex.Adapter.Config


  # public


  def start_agent(openstex_client, opts) do
    otp_app = Keyword.get(opts, :otp_app, :false) || raise("Client has not been configured correctly, missing `:otp_app`")

    ovh_client = Module.concat(openstex_client, Ovh)
    Application.ensure_all_started(:ex_ovh)
    unless supervisor_exists?(ovh_client), do: ovh_client.start_link()
    identity = Utils.create_identity(openstex_client, otp_app)

    Agent.start_link(fn -> config({openstex_client, ovh_client}, otp_app, identity) end, name: agent_name(openstex_client))
  end


  @doc "Gets the rackspace related config variables from a supervised Agent"
  def ovh_config(openstex_client) do
    Agent.get(agent_name(openstex_client), fn(config) -> config[:ovh] end)
  end


  @doc :false
  def swift_service_name(), do: "swift"


  @doc :false
  def swift_service_type(), do: "object-store"


  # private


  defp config({openstex_client, ovh_client}, otp_app, identity) do
    swift_config = swift_config(openstex_client, otp_app)
    keystone_config = keystone_config(openstex_client, otp_app, identity)
    [
     ovh: ovh_client.ovh_config(),
     keystone: keystone_config,
     swift: swift_config,
     hackney: hackney_config(openstex_client, otp_app)
    ]
  end

  defp keystone_config(openstex_client, otp_app, identity) do

    keystone_config = get_keystone_config_from_env(openstex_client, otp_app)

    tenant_id = keystone_config[:tenant_id] ||
                identity.token.tenant.id ||
                raise("cannot retrieve the tenant_id for keystone")

    user_id =   keystone_config[:user_id] ||
                identity.user.id ||
                raise("cannot retrieve the user_id for keystone")

    endpoint =  keystone_config[:endpoint] ||
                "https://auth.cloud.ovh.net/v2.0"

    [
    tenant_id: tenant_id,
    user_id: user_id,
    endpoint: endpoint
    ]
  end

  defp swift_config(openstex_client, otp_app) do

    swift_config = get_swift_config_from_env(openstex_client, otp_app)

    account_temp_url_key1 = get_account_temp_url(openstex_client, otp_app, :key1) ||
                            swift_config[:account_temp_url_key1] ||
                            :nil

    if account_temp_url_key1 != :nil && swift_config[:account_temp_url_key1] != account_temp_url_key1 do
      error_msg =
      "Warning, the `account_temp_url_key1` for the elixir `config.exs` for the swift client " <>
      "#{inspect openstex_client} does not match the `X-Account-Meta-Temp-Url-Key` on the server. " <>
      "This issue should probably be addressed. See Openstex.Adapter.Config.set_account_temp_url_key1/2."
      IO.puts(:stdio, error_msg)
    end

    account_temp_url_key2 = get_account_temp_url(openstex_client, otp_app, :key2) ||
                            swift_config[:account_temp_url_key2] ||
                            :nil

    if account_temp_url_key2 != :nil && swift_config[:account_temp_url_key2] != account_temp_url_key2 do
      error_msg =
      "Warning, the `account_temp_url_key2` for the elixir `config.exs` for the swift client " <>
      "#{inspect openstex_client} does not match the `X-Account-Meta-Temp-Url-Key-2` on the server. " <>
      "This issue should probably be addressed. See Openstex.Adapter.Config.set_account_temp_url_key2/2."
      IO.puts(:stdio, error_msg)
    end

    region = swift_config[:region] || "SBG1"

    [
    account_temp_url_key1: account_temp_url_key1,
    account_temp_url_key2: account_temp_url_key2,
    region: region
    ]
  end


  defp hackney_config(openstex_client, otp_app) do
    hackney_config = get_hackney_config_from_env(openstex_client, otp_app)
    connect_timeout = hackney_config[:timeout] || 30000
    recv_timeout = hackney_config[:recv_timeout] || (60000 * 30)
    [
    timeout: connect_timeout,
    recv_timeout: recv_timeout
    ]
  end


  defp get_account_temp_url(openstex_client, otp_app, key_atom) do

    ovh_client = Module.concat(openstex_client, Ovh)
    Application.ensure_all_started(:ex_ovh)
    unless supervisor_exists?(ovh_client), do: ovh_client.start_link()

    identity = Utils.create_identity(openstex_client, otp_app)
    x_auth_token = Map.get(identity, :token) |> Map.get(:id)
    endpoint = get_public_url(openstex_client, otp_app, identity)

    headers =
    @default_headers ++
    [
      {
        "X-Auth-Token", x_auth_token
      }
    ]
    |> Enum.into(%{})

    header =
    case key_atom do
      :key1 -> "X-Account-Meta-Temp-Url-Key"
      :key2 -> "X-Account-Meta-Temp-Url-Key-2"
    end

    request =
    %HTTPipe.Request{
      method: :get,
      url: endpoint,
      body: :nil,
      headers: headers
    }
    {:ok, conn} = %HTTPipe.Conn{request: request, adapter_options: @default_options, adapter: @default_adapter}
    |> Openstex.Request.request(:nil)

    HTTPipe.Conn.get_resp_header(conn, header)
  end

  defp get_public_url(openstex_client, otp_app, identity) do

    swift_config = get_swift_config_from_env(openstex_client, otp_app)

    region = swift_config[:region] || @default_ovh_region

    identity
    |> Map.get(:service_catalog)
    |> Enum.find(fn(%Identity.Service{} = service) -> service.name == swift_service_name() && service.type == swift_service_type() end)
    |> Map.get(:endpoints)
    |> Enum.find(fn(%Identity.Endpoint{} = endpoint) -> endpoint.region == region end)
    |> Map.get(:public_url)
  end

  defp supervisor_exists?(ovh_client) do
    Module.concat(ExOvh.Config, ovh_client) in Process.registered()
  end


end