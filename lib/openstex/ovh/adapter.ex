defmodule Openstex.Adapters.Ovh do
  @moduledoc :false
  @behaviour Openstex.Adapter

  def config(), do: Openstex.Adapters.Ovh.Config
  def keystone(), do: Openstex.Adapters.Ovh.Keystone

end

