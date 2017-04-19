# Openstex.Adapters.Ovh

An adapter for [Openstex](https://github.com/stephenmoloney/openstex)
for the [OVH API](https://github.com/stephenmoloney/ex_ovh).


## Steps to getting started

### (1) Installation

- Add `:openstex_adapters_ovh` to your project list of dependencies.

```elixir
defp deps() do
  [
    {:openstex_adapters_ovh, ">= 0.3.4"}
  ]
end
```

- Ensure `openstex_adapters_ovh` is started before your application:

```elixir
def application do
  [applications: [:openstex_adapters_ovh]]
end
```

### (2) Configure the Adapter Clients

#### Generating the OVH `application key`, `application secret` and `consumer key`.

- This may be done manually by going to `https://eu.api.ovh.com/createApp/` and following the directions outlined by `OVH` at
[their first steps guide](https://api.ovh.com/g934.first_step_with_api).

- Alternatively, this may be achieved by running a mix task. This saves me a lot of time when generating a new application.

- [Documentation here](https://github.com/stephenmoloney/ex_ovh/blob/master/docs/mix_task.md)

- The mix task should create a `.env` file in the root directory similar to:

```shell
export MY_APP_CLIENT_APPLICATION_KEY="app_key"
export MY_APP_CLIENT_APPLICATION_SECRET="app_secret"
export MY_APP_CLIENT_CONSUMER_KEY="app_consumer_key"
```

- Add the configuration for the openstack components of the client to `.env`:

```shell
export MY_APP_CLIENT_TENANT_ID="tenant_id"
export MY_APP_CLIENT_USER_ID="user_id"
export MY_APP_CLIENT_TEMP_URL_KEY1="key1"
export MY_APP_CLIENT_TEMP_URL_KEY2="key2"
```

- The final confiruation file in `config.exs` should look like follows:

```elixir
config :my_app, MyApp.Client,
    adapter: Openstex.Adapters.Ovh,
    ovh: [
      application_key: System.get_env("MY_APP_CLIENT_APPLICATION_KEY"),
      application_secret: System.get_env("MY_APP_CLIENT_OVH_APPLICATION_SECRET"),
      consumer_key: System.get_env("MY_APP_CLIENT_OVH_CONSUMER_KEY")
    ],
    keystone: [
      tenant_id: System.get_env("MY_APP_CLIENT_TENANT_ID"), # mandatory, corresponds to an ovh project id or ovh servicename
      user_id: System.get_env("MY_APP_CLIENT_USER_ID"), # optional, if absent a user will be created using the ovh api.
      endpoint: "https://auth.cloud.ovh.net/v2.0"
    ],
    swift: [
      account_temp_url_key1: System.get_env("MY_APP_CLIENT_TEMP_URL_KEY1"), # defaults to :nil if absent
      account_temp_url_key2: System.get_env("MY_APP_CLIENT_TEMP_URL_KEY2"), # defaults to :nil if absent
      region: :nil #  set to "SBG3" or "GRA3" or "BHS3" -- but check with OVH as this may change.
    ],
    hackney: [
      timeout: 20000,
      recv_timeout: 40000
    ]

config :httpipe,
  adapter: HTTPipe.Adapters.Hackney
```


### (3) Creating the client module

- The client module is used for making requests.

- Create the client module similar as follows:

```elixir
defmodule MyApp.Client do
  @moduledoc :false
  use Openstex.Client, otp_app: :my_app, client: __MODULE__

  defmodule Swift do
    @moduledoc :false
    use Openstex.Swift.V1.Helpers, otp_app: :my_app, client: MyApp.Client
  end

  defmodule Ovh do
    @moduledoc :false
    use ExOvh.Client, otp_app: :my_app, client: __MODULE__
  end
end
```

### (4) Adding the client to the supervision tree

```elixir
def start(_type, _args) do
  import Supervisor.Spec, warn: false
  spec1 = [supervisor(MyApp.Endpoint, [])]
  spec2 = [supervisor(MyApp.Client, [])]
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(spec1 ++ spec2, opts)
end
```

### (5) Using the client module

#### To use the client for the `Openstex` API:

- Creating a container using the `Openstex.Swift.V1` request generator and then sending the request.
```elixir
  MyApp.Client.start_link()
  Openstex.Swift.V1.create_container("new_container", "my_swift_account") |> MyApp.Client.request()
```

- Uploading a file using the the `Openstex` Swift Helper:
```elixir
  file_path = Path.join(Path.expand(__DIR__), "priv/test.txt")
  MyApp.Client.Swift.upload_file!(file_path, "nested_folder/server_object.txt", "new_container")
```

- Listing the objects using the `Openstex` Swift Helper:
```elixir
  MyApp.Client.Swift.list_objects!("new_container")
```


#### To use the client for the `OVH` API:

- Getting prices with the `ExOvh.V1.Cloud` request generator and then sending the request.
```elixir
  ExOvh.V1.Cloud.get_prices() |> MyApp.Client.Ovh.request()
```
