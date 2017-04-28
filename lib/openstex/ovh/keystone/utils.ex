defmodule Openstex.Adapters.Ovh.Keystone.Utils do
  @moduledoc :false
  alias Openstex.Keystone.V2.Helpers, as: Keystone
  alias Openstex.Adapters.Ovh.Config


  @doc :false
  @spec create_identity(atom, atom) :: Identity.t | no_return
  def create_identity(openstex_client, otp_app \\ :nil) do
    ovh_client = Module.concat(openstex_client, Ovh)
    Application.ensure_all_started(:ex_ovh)
    unless supervisor_exists?(ovh_client), do: ovh_client.start_link()

    keystone_config = Config.get_config_from_env(openstex_client, otp_app) |> Keyword.get(:keystone, :nil) ||
                      openstex_client.config().keystone_config(openstex_client)
    tenant_id = Keyword.fetch!(keystone_config, :tenant_id)
    ovh_user = ExOvh.V1.Cloud.get_users(tenant_id)
    |> ovh_client.request!()
    |> Map.get(:response) |> Map.get(:body)
    |> Enum.find(:nil,
      fn(user) -> %{"description" => _description} = user end
    )

    ovh_user_id =
    case ovh_user do
      :nil ->
        # create user for the description
        ExOvh.V1.Cloud.create_user(tenant_id, "ex_ovh")
        |> ovh_client.request!()
        |> Map.get(:response) |> Map.get(:body)
        |> Map.get("id")
      ovh_user ->
        ovh_user["id"]
    end


    {:ok, conn} = get_credentials(ovh_client, tenant_id, ovh_user_id)
    password = conn.response.body["password"] || raise("Password not found")
    username = conn.response.body["username"] || raise("Username not found")
    endpoint = keystone_config[:endpoint] || "https://auth.cloud.ovh.net/v2.0"

    # make sure the regenerate credentials (in the external ovh api) had a chance to take effect
    :timer.sleep(1000)

    Keystone.authenticate!(endpoint, username, password, [tenant_id: tenant_id])
  end

  defp supervisor_exists?(ovh_client) do
    Module.concat(ExOvh.Config, ovh_client) in Process.registered()
  end

  defp get_credentials(ovh_client, tenant_id, ovh_user_id) do
    with {:ok, conn} <- ExOvh.V1.Cloud.regenerate_credentials(tenant_id, ovh_user_id)
                        |> ovh_client.request() do
      {:ok, conn}
    else
      {:error, _conn} -> get_credentials(ovh_client, tenant_id, ovh_user_id, 3)
    end
  end
  defp get_credentials(ovh_client, tenant_id, ovh_user_id, retries) when is_integer(retries) do
    with {:ok, conn} <- ExOvh.V1.Cloud.regenerate_credentials(tenant_id, ovh_user_id)
                        |> ovh_client.request() do
      {:ok, conn}
    else
      {:error, % HTTPipe.Conn{response: %HTTPipe.Response{status_code: 500}}} ->
        get_credentials(tenant_id, ovh_user_id, (retries - 1))
      {:error, conn} ->
        raise(conn.response.body["message"])
    end
  end
  defp get_credentials(ovh_client, tenant_id, ovh_user_id, 0) do
    with {:ok, conn} <- ExOvh.V1.Cloud.regenerate_credentials(tenant_id, ovh_user_id)
                        |> ovh_client.request() do
      {:ok, conn}
    else
      {:error, conn} ->
        raise(conn.response.body["message"])
    end
  end



end

