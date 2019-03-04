defmodule ElixirElasticsearch.IndexerSupervisor do
  @moduledoc """
  Supervisor for ES Indexer.
  """

  use Supervisor

  alias ElixirElasticsearch.IndexerGenserver

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    supervise([], strategy: :one_for_one)
  end

  @doc """
  Finds or create the Index Genserver in the cluster
  """
  def get_indexer_process do
    case :global.whereis_name(ElixirElasticsearch.IndexerGenserver) do
      :undefined -> new_indexer()
      pid -> {:ok, pid}
    end
  end

  defp new_indexer do
    Supervisor.start_child(__MODULE__, IndexerGenserver)
  end
end
