defmodule ElixirElasticsearch.ElasticsearchCluster do
  @moduledoc false
  use Elasticsearch.Cluster, otp_app: :elixir_elasticsearch
end
