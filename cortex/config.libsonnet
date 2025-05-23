{
  _config+: {
    namespace: error 'must define namespace',
    cluster: error 'must define cluster',
    replication_factor: 3,
    external_url: error 'must define external url for cluster',

    aws_region: error 'must specify AWS region',

    // If false, ingesters are not unregistered on shutdown and left in the ring with
    // the LEAVING state. Setting to false prevents series resharding during ingesters rollouts,
    // but requires to:
    // 1. Either manually forget ingesters on scale down or invoke the /shutdown endpoint
    // 2. Ensure ingester ID is preserved during rollouts
    unregister_ingesters_on_shutdown: true,

    // Controls whether multiple pods for the same service can be scheduled on the same node.
    cortex_distributor_allow_multiple_replicas_on_same_node: false,
    cortex_ruler_allow_multiple_replicas_on_same_node: false,
    cortex_querier_allow_multiple_replicas_on_same_node: false,
    cortex_query_frontend_allow_multiple_replicas_on_same_node: false,

    test_exporter_enabled: false,
    test_exporter_start_time: error 'must specify test exporter start time',
    test_exporter_user_id: error 'must specify test exporter used id',

    querier: {
      replicas: 6,
      concurrency: 8,
    },

    queryFrontend: {
      replicas: 2,
    },

    jaeger_agent_host: null,

    blocks_storage_backend: error "must specify $._config.blocks_storage_backend . Available options are 'gcs', 's3', 'azure'",
    blocks_storage_bucket_name: error 'must specify blocks storage bucket name',
    blocks_storage_s3_endpoint: 's3.dualstack.%s.amazonaws.com' % $._config.aws_region,
    blocks_storage_azure_account_name: if $._config.blocks_storage_backend == 'azure' then error 'must specify azure account name' else '',
    blocks_storage_azure_account_key: if $._config.blocks_storage_backend == 'azure' then error 'must specify azure account key' else '',

    store_gateway_replication_factor: 3,

    ingester: {
      // These config options are only for the chunks storage.
      wal_dir: '/wal_data',
      statefulset_disk: '150Gi',
    },

    memcached_index_queries_enabled: true,
    memcached_index_queries_max_item_size_mb: 5,

    memcached_chunks_enabled: true,
    memcached_chunks_max_item_size_mb: 1,

    memcached_metadata_enabled: $._config.storage_engine == 'blocks',
    memcached_metadata_max_item_size_mb: 1,

    // The query-tee is an optional service which can be used to send
    // the same input query to multiple backends and make them compete
    // (comparing performances).
    query_tee_enabled: false,
    query_tee_backend_endpoints: [],
    query_tee_backend_preferred: '',

    grpcConfig:: {
      'server.grpc.keepalive.min-time-between-pings': '10s',
      'server.grpc.keepalive.ping-without-stream-allowed': true,
    },

    ingesterClientConfig:: {
      'ingester.client.grpc-compression': 'snappy-block',
    },

    genericBlocksStorageConfig:: {
      'store.engine': 'blocks',
    },

    // Ignore blocks in querier, ruler and store-gateways for the last 11h
    ignore_blocks_within: '11h',

    // No need to look at store for data younger than 12h, as ingesters have all of it.
    query_store_after: '12h',

    // Ingesters don't have data older than 13h, no need to ask them.
    query_ingesters_within: '13h',

    queryBlocksStorageConfig:: {
      'blocks-storage.bucket-store.sync-dir': '/data/tsdb',
      'blocks-storage.bucket-store.ignore-blocks-within': $._config.ignore_blocks_within,
      'blocks-storage.bucket-store.ignore-deletion-marks-delay': '1h',

      'store-gateway.sharding-enabled': true,
      'store-gateway.sharding-ring.store': 'consul',
      'store-gateway.sharding-ring.consul.hostname': 'consul.%s.svc.cluster.local:8500' % $._config.namespace,
      'store-gateway.sharding-ring.prefix': '',
      'store-gateway.sharding-ring.replication-factor': $._config.store_gateway_replication_factor,
    },
    gcsBlocksStorageConfig:: $._config.genericBlocksStorageConfig {
      'blocks-storage.backend': 'gcs',
      'blocks-storage.gcs.bucket-name': $._config.blocks_storage_bucket_name,
    },
    s3BlocksStorageConfig:: $._config.genericBlocksStorageConfig {
      'blocks-storage.backend': 's3',
      'blocks-storage.s3.bucket-name': $._config.blocks_storage_bucket_name,
      'blocks-storage.s3.endpoint': $._config.blocks_storage_s3_endpoint,
    },
    azureBlocksStorageConfig:: $._config.genericBlocksStorageConfig {
      'blocks-storage.backend': 'azure',
      'blocks-storage.azure.container-name': $._config.blocks_storage_bucket_name,
      'blocks-storage.azure.account-name': $._config.blocks_storage_azure_account_name,
      'blocks-storage.azure.account-key': $._config.blocks_storage_azure_account_key,
      'blocks-storage.azure.endpoint-suffix': 'blob.core.windows.net',
    },

    blocksStorageConfig:
      if $._config.blocks_storage_backend == 'gcs' then $._config.gcsBlocksStorageConfig
      else if $._config.blocks_storage_backend == 's3' then $._config.s3BlocksStorageConfig
      else if $._config.blocks_storage_backend == 'azure' then $._config.azureBlocksStorageConfig
      else $._config.genericBlocksStorageConfig,

    // Querier component config (shared between the ruler and querier).
    queryConfig: {
      'runtime-config.file': '/etc/cortex/overrides.yaml',

      // Don't allow individual queries of longer than 32days.  Due to day query
      // splitting in the frontend, the reality is this only limits rate(foo[32d])
      // type queries. 32 days to allow for comparision over the last month (31d) and
      // then some.
      'store.max-query-length': '768h',
      'querier.query-ingesters-within': $._config.query_ingesters_within,
      'querier.query-store-after': $._config.query_store_after,
    },

    // PromQL query engine config (shared between all services running PromQL engine, like the ruler and querier).
    queryEngineConfig: {
      // Keep it even if empty, to allow downstream projects to easily configure it.
    },

    ringConfig: {
      'consul.hostname': 'consul.%s.svc.cluster.local:8500' % $._config.namespace,
      'ring.prefix': '',
    },

    // Some distributor config is shared with the querier.
    distributorConfig: {
      'distributor.replication-factor': $._config.replication_factor,
      'distributor.shard-by-all-labels': true,
      'distributor.health-check-ingesters': true,
      'ring.heartbeat-timeout': '10m',
    },

    ruler_enabled: false,
    ruler_client_type: error 'you must specify a storage backend type for the ruler (azure, gcs, s3, local)',
    ruler_storage_bucket_name: error 'must specify the ruler storage bucket name',
    ruler_storage_azure_account_name: error 'must specify the ruler storage Azure account name',
    ruler_storage_azure_account_key: error 'must specify the ruler storage Azure account key',

    rulerClientConfig:
      {
        'ruler-storage.backend': $._config.ruler_client_type,
      } +
      {
        gcs: {
          'ruler-storage.gcs.bucket-name': $._config.ruler_storage_bucket_name,
        },
        s3: {
          'ruler-storage.s3.region': $._config.aws_region,
          'ruler-storage.s3.bucket-name': $._config.ruler_storage_bucket_name,
          'ruler-storage.s3.endpoint': 's3.dualstack.%s.amazonaws.com' % $._config.aws_region,
        },
        azure: {
          'ruler-storage.azure.container-name': $._config.ruler_storage_bucket_name,
          'ruler-storage.azure.account-name': $._config.ruler_storage_azure_account_name,
          'ruler-storage.azure.account-key': $._config.ruler_storage_azure_account_key,
          'ruler-storage.azure.endpoint-suffix': 'blob.core.windows.net',
        },
        'local': {
          'ruler-storage.local.directory': $._config.ruler_local_directory,
        },
      }[$._config.ruler_client_type],

    alertmanager: {
      replicas: 3,
      sharding_enabled: false,
      gossip_port: 9094,
      fallback_config: {},
      ring_store: 'consul',
      ring_hostname: 'consul.%s.svc.cluster.local:8500' % $._config.namespace,
      ring_replication_factor: $._config.replication_factor,
    },

    alertmanager_client_type: error 'you must specify a storage backend type for the alertmanager (azure, gcs, s3, local)',
    alertmanager_s3_bucket_name: error 'you must specify the alertmanager S3 bucket name',
    alertmanager_gcs_bucket_name: error 'you must specify a GCS bucket name',
    alertmanager_azure_container_name: error 'you must specify an Azure container name',

    alertmanagerStorageClientConfig:
      {
        'alertmanager-storage.backend': $._config.alertmanager_client_type,
      } +
      {
        azure: {
          'alertmanager-storage.azure.account-key': $._config.alertmanager_azure_account_key,
          'alertmanager-storage.azure.account-name': $._config.alertmanager_azure_account_name,
          'alertmanager-storage.azure.container-name': $._config.alertmanager_azure_container_name,
          'alertmanager-storage.azure.endpoint-suffix': 'blob.core.windows.net',
        },
        gcs: {
          'alertmanager-storage.gcs.bucket-name': $._config.alertmanager_gcs_bucket_name,
        },
        s3: {
          'alertmanager-storage.s3.region': $._config.aws_region,
          'alertmanager-storage.s3.bucket-name': $._config.alertmanager_s3_bucket_name,
        },
        'local': {
          'alertmanager-storage.local.path': $._config.alertmanager_local_directory,
        },
      }[$._config.alertmanager_client_type],

    // === Per-tenant usage limits. ===
    //
    // These are the defaults.
    limits: $._config.overrides.extra_small_user,

    // These are all the flags for the default limits.
    distributorLimitsConfig: {
      'distributor.ingestion-rate-limit-strategy': 'global',
      'distributor.ingestion-rate-limit': $._config.limits.ingestion_rate,
      'distributor.ingestion-burst-size': $._config.limits.ingestion_burst_size,
    },
    ingesterLimitsConfig: {
      'ingester.max-series-per-user': $._config.limits.max_series_per_user,
      'ingester.max-series-per-metric': $._config.limits.max_series_per_metric,
      'ingester.max-global-series-per-user': $._config.limits.max_global_series_per_user,
      'ingester.max-global-series-per-metric': $._config.limits.max_global_series_per_metric,
    },
    rulerLimitsConfig: {
      'ruler.max-rules-per-rule-group': $._config.limits.ruler_max_rules_per_rule_group,
      'ruler.max-rule-groups-per-tenant': $._config.limits.ruler_max_rule_groups_per_tenant,
    },
    compactorLimitsConfig: {
      'compactor.blocks-retention-period': $._config.limits.compactor_blocks_retention_period,
    },

    limitsConfig: self.distributorLimitsConfig + self.ingesterLimitsConfig + self.rulerLimitsConfig + self.compactorLimitsConfig,

    overrides_configmap: 'overrides',

    overrides: {
      extra_small_user:: {
        max_series_per_user: 0,  // Disabled in favour of the max global limit
        max_series_per_metric: 0,  // Disabled in favour of the max global limit

        // Our limit should be 100k, but we need some room of about ~50% to take rollouts into account
        max_global_series_per_user: 150000,
        max_global_series_per_metric: 20000,

        ingestion_rate: 10000,
        ingestion_burst_size: 200000,

        // 700 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 35,

        // No retention for now.
        compactor_blocks_retention_period: '0',

        ingestion_tenant_shard_size: 3,
      },

      medium_small_user:: {
        max_series_per_user: 0,  // Disabled in favour of the max global limit
        max_series_per_metric: 0,  // Disabled in favour of the max global limit

        max_global_series_per_user: 300000,
        max_global_series_per_metric: 30000,

        ingestion_rate: 30000,
        ingestion_burst_size: 300000,

        // 1000 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 50,

        ingestion_tenant_shard_size: 9,
      },

      small_user:: {
        max_series_per_metric: 0,  // Disabled in favour of the max global limit
        max_series_per_user: 0,  // Disabled in favour of the max global limit

        max_global_series_per_user: 1000000,
        max_global_series_per_metric: 100000,

        ingestion_rate: 100000,
        ingestion_burst_size: 1000000,

        // 1400 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 70,

        ingestion_tenant_shard_size: 15,
      },

      medium_user:: {
        max_series_per_metric: 0,  // Disabled in favour of the max global limit
        max_series_per_user: 0,  // Disabled in favour of the max global limit

        max_global_series_per_user: 3000000,  // 3M
        max_global_series_per_metric: 300000,  // 300K

        ingestion_rate: 350000,  // 350K
        ingestion_burst_size: 3500000,  // 3.5M

        // 1800 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 90,

        ingestion_tenant_shard_size: 30,
      },

      big_user:: {
        max_series_per_metric: 0,  // Disabled in favour of the max global limit
        max_series_per_user: 0,  // Disabled in favour of the max global limit

        max_global_series_per_user: 6000000,  // 6M
        max_global_series_per_metric: 600000,  // 600K

        ingestion_rate: 700000,  // 700K
        ingestion_burst_size: 7000000,  // 7M

        // 2200 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 110,

        ingestion_tenant_shard_size: 60,
      },

      super_user:: {
        compactor_tenant_shard_size: 2,
        max_series_per_metric: 0,  // Disabled in favour of the max global limit
        max_series_per_user: 0,  // Disabled in favour of the max global limit

        max_global_series_per_user: 12000000,  // 12M
        max_global_series_per_metric: 1200000,  // 1.2M

        ingestion_rate: 1500000,  // 1.5M
        ingestion_burst_size: 15000000,  // 15M

        // 2600 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 130,

        ingestion_tenant_shard_size: 120,
      },

      // This user class has limits increased by +50% compared to the previous one.
      mega_user+:: {
        compactor_tenant_shard_size: 2,
        max_series_per_metric: 0,  // Disabled in favour of the max global limit
        max_series_per_user: 0,  // Disabled in favour of the max global limit

        max_global_series_per_user: 16000000,  // 16M
        max_global_series_per_metric: 1600000,  // 1.6M

        ingestion_rate: 2250000,  // 2.25M
        ingestion_burst_size: 22500000,  // 22.5M

        // 3000 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 150,

        ingestion_tenant_shard_size: 180,
      },

      user_24M:: {  // 50% more than previous
        compactor_tenant_shard_size: 4,
        max_series_per_metric: 0,  // Disabled in favour of the max global limit
        max_series_per_user: 0,  // Disabled in favour of the max global limit

        max_global_series_per_user: 24000000,  // 24M
        max_global_series_per_metric: 2400000,  // 2.4M

        ingestion_rate: 3000000,  // 3M
        ingestion_burst_size: 30000000,  // 30M

        // 3400 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 170,

        ingestion_tenant_shard_size: 270,
      },

      user_32M:: {  // 33% more than previous
        compactor_tenant_shard_size: 4,
        max_series_per_metric: 0,  // Disabled in favour of the max global limit
        max_series_per_user: 0,  // Disabled in favour of the max global limit

        max_global_series_per_user: 32000000,  // 32M
        max_global_series_per_metric: 3200000,  // 3.2M

        ingestion_rate: 4500000,  // 4.5M
        ingestion_burst_size: 45000000,  // 45M

        // 3800 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 190,

        ingestion_tenant_shard_size: 360,
      },

      user_48M:: {  // 50% more than previous
        compactor_tenant_shard_size: 8,
        max_series_per_metric: 0,  // Disabled in favour of the max global limit
        max_series_per_user: 0,  // Disabled in favour of the max global limit

        max_global_series_per_user: 48000000,  // 48M
        max_global_series_per_metric: 4800000,  // 4.8M

        ingestion_rate: 6000000,  // 6M
        ingestion_burst_size: 60000000,  // 60M

        // 4200 rules
        ruler_max_rules_per_rule_group: 20,
        ruler_max_rule_groups_per_tenant: 210,

        ingestion_tenant_shard_size: 540,
      },
    },

    // if not empty, passed to overrides.yaml as another top-level field
    multi_kv_config: {},

    enable_pod_priorities: true,

    alertmanager_enabled: false,

    // Enables query-scheduler component, and reconfigures querier and query-frontend to use it.
    query_scheduler_enabled: true,

    // Enables streaming of chunks from ingesters using blocks.
    // Changing it will not cause new rollout of ingesters, as it gets passed to them via runtime-config.
    ingester_stream_chunks_when_using_blocks: true,

    // Ingester limits are put directly into runtime config, if not null. Available limits:
    ingester_instance_limits: {
      // max_inflight_push_requests: 0,  // Max inflight push requests per ingester. 0 = no limit.
      // max_ingestion_rate: 0,  // Max ingestion rate (samples/second) per ingester. 0 = no limit.
      max_series: 4.8e+6,  // Max number of series per ingester. 0 = no limit. 4.8 million is closely tied to 15Gb in requests per ingester
      // max_tenants: 0,  // Max number of tenants per ingester. 0 = no limit.
    },

    // if we disable this, we need to make sure we set the resource limits
    // Disabling this can potentially increase cortex performance,
    // but it will also cause performance inconsistencies
    gomaxprocs_based_on_cpu_requests: true,
    gomemlimit_based_on_mem_requests: true,

    gomaxprocs_resource:
      if $._config.gomaxprocs_based_on_cpu_requests then
        'requests.cpu'
      else
        'limits.cpu',

    gomemlimit_resource:
      if $._config.gomemlimit_based_on_mem_requests then
        'requests.memory'
      else
        'limits.memory',
  },

  go_container_mixin::
    local container = $.core.v1.container;
    container.withEnvMixin([
      container.envType.withName('GOMAXPROCS') +
      container.envType.valueFrom.resourceFieldRef.withResource($._config.gomaxprocs_resource),
      container.envType.withName('GOMEMLIMIT') +
      container.envType.valueFrom.resourceFieldRef.withResource($._config.gomemlimit_resource),
    ]),

  local configMap = $.core.v1.configMap,

  overrides_config:
    configMap.new($._config.overrides_configmap) +
    configMap.withData({
      'overrides.yaml': $.util.manifestYaml(
        { overrides: $._config.overrides }
        + (if std.length($._config.multi_kv_config) > 0 then { multi_kv_config: $._config.multi_kv_config } else {})
        + (if $._config.ingester_stream_chunks_when_using_blocks then { ingester_stream_chunks_when_using_blocks: true } else {})
        + (if $._config.ingester_instance_limits != null then { ingester_limits: $._config.ingester_instance_limits } else {}),
      ),
    }),

  // This removed the CPU limit from the config.  NB won't show up in subset
  // diffs, but ks apply will do the right thing.
  removeCPULimitsMixin:: {
    resources+: {
      // Can't use super.memory in limits, as we want to
      // override the whole limits struct.
      local memoryLimit = super.limits.memory,

      limits: {
        memory: memoryLimit,
      },
    },
  },
}
