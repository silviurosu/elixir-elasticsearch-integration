defmodule ElixirElasticsearch.IndexerGenserver do
  @moduledoc """
  Genserver that takes care of the reindex requests.
  There is a single running instance of this process in the cluster.
  We pipe them all via a GenServer to not overload the ES server with too many requests.
  All further requests will wait in the queue.

  Example usages:
    ElixirElasticsearch.IndexerGenserver.index_restaurant("demo_restaurant")
    ElixirElasticsearch.IndexerGenserver.hot_swap
  """

  @moduledoc authors: ["Silviu Rosu"]

  use GenServer

  require Logger

  alias Elasticsearch.Cluster.Config
  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk
  alias ElixirElasticsearch.RestaurantsSearchParams
  alias ElixirElasticsearch.ElasticsearchCluster
  alias ElixirElasticsearch.ElasticsearchStore
  alias ElixirElasticsearch.IndexerSupervisor

  alias __MODULE__, as: M

  def child_specs(args) do
    %{
      id: M,
      start: {M, :start_link, args},
      restart: :transient,
      type: :worker
    }
  end

  def start_link(_args) do
    GenServer.start_link(M, [], name: process_name())
  end

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  def process_name, do: {:global, M}

  @doc """
  Reindex all the restaurants from the channel.
  """
  def index_all do
    {:ok, pid} = IndexerSupervisor.get_indexer_process()
    GenServer.cast(pid, {:index_all})
  end

  @doc """
  Hot swap index. Zero downtime index rebuilding.
  It created a new index where it sends all the documents then replaces the indexes
  """
  def hot_swap do
    {:ok, pid} = IndexerSupervisor.get_indexer_process()
    GenServer.cast(pid, {:hot_swap})
  end

  @doc """
  Reindex all the restaurants from all the channels for the specified restaurant.
  """
  def index_restaurant(restaurant) do
    {:ok, pid} = IndexerSupervisor.get_indexer_process()
    GenServer.cast(pid, {:index_restaurant, restaurant})
  end

  @impl GenServer
  def handle_cast({:index_all}, state) do
    %RestaurantsSearchParams{}
    |> ElasticsearchStore.stream()
    |> Enum.each(&index_restaurant/1)

    {:noreply, state}
  end

  def handle_cast({:hot_swap}, state) do
    config = Config.get(ElasticsearchCluster)
    alias = String.to_existing_atom(index_name())
    name = Index.build_name(alias)
    %{settings: settings_file} = index_config = config[:indexes][alias]

    with :ok <- Index.create_from_file(config, name, settings_file),
         bulk_upload(config, name, index_config),
         :ok <- Index.alias(config, name, alias),
         :ok <- Index.clean_starting_with(config, alias, 2),
         :ok <- Index.refresh(config, name) do
      :ok
    else
      _err ->
        nil
        # Use your favorite error reporting service:
        # Bugsnag.report(err, severity: "warn")
    end

    {:noreply, state}
  end

  # TODO - User this when ES library permits to send params to stream
  # See Elasticsearch.Index.Bulk#92
  # def handle_cast({:index_channel, channel}, state) do
  #   config = Config.get(ElasticsearchCluster)
  #   name = index_name()
  #   index_config = config[:indexes][String.to_existing_atom(name)]

  #   case Bulk.upload(config, name, index_config) do
  #     :ok ->
  #       nil

  #     {:error, errors} ->
  #       Bugsnag.report(
  #         ElasticsearchError.exception("Errors encountered indexing channel restaurants"),
  #         severity: "warn",
  #         metadata: %{channel: channel, errors: errors}
  #       )
  #   end

  #   Index.refresh(config, name)

  #   {:noreply, state}
  # end

  def handle_cast({:index_restaurant, restaurant}, state) do
    restaurant
    |> build_restaurant_params()
    |> ElasticsearchStore.stream()
    |> Enum.each(&index_restaurant_data/1)

    {:noreply, state}
  end

  defp bulk_upload(config, name, index_config) do
    case Bulk.upload(config, name, index_config) do
      :ok ->
        :ok

      {:error, errors} = err ->
        Logger.error(fn -> inspect(errors) end)

        # Bugsnag.report(
        #   ElasticsearchError.exception("Errors encountered indexing restaurants"),
        #   severity: "warn",
        #   metadata: %{errors: errors}
        # )

        err
    end
  end

  defp build_restaurant_params(restaurant) when is_integer(restaurant) do
    %RestaurantsSearchParams{restaurant_id: restaurant}
  end

  defp build_restaurant_params(restaurant) when is_binary(restaurant) do
    %RestaurantsSearchParams{restaurant_permalink: restaurant}
  end

  defp index_restaurant_data(restaurant) do
    str_id = Integer.to_string(restaurant.id)

    case Elasticsearch.put_document(ElasticsearchCluster, restaurant, index_name()) do
      {:ok, _} ->
        Logger.info(fn -> "Succesfully indexed restaurant #{str_id}." end)

      {:error, %HTTPoison.Error{id: nil, reason: :timeout}} ->
        Logger.error(fn -> "Timeout indexing restaurant #{str_id}" end)

      # Bugsnag.report(
      #   ElasticsearchError.exception("Timeout indexing restaurant #{str_id}"),
      #   severity: "warn",
      #   metadata: %{restaurant: restaurant}
      # )

      {:error, %Elasticsearch.Exception{message: message, raw: _raw_error}} ->
        Logger.error(fn -> message end)
        Logger.error(fn -> inspect(restaurant) end)

        # Bugsnag.report(
        #   ElasticsearchError.exception(message),
        #   severity: "warn",
        #   metadata: %{restaurant: restaurant, message: message, elasticsearch_error: raw_error}
        # )
    end
  end

  defp index_name do
    elastic_env = Application.get_env(:elixir_elasticsearch, :ELASTICSEARCH_ENV)
    "restaurants_demo_#{elastic_env}"
  end
end
