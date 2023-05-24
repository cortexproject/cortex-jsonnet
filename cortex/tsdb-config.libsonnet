{
  _config+:: {
    // Enforce blocks storage
    storage_backend: 'none',
    storage_engine: 'blocks',

    // Allow to configure the ingester disk.
    cortex_ingester_data_disk_size: '100Gi',
    cortex_ingester_data_disk_class: 'fast',

    // Allow to configure the store-gateway disk.
    cortex_store_gateway_data_disk_size: '50Gi',
    cortex_store_gateway_data_disk_class: 'standard',

    // Allow to configure the compactor disk.
    cortex_compactor_data_disk_size: '250Gi',
    cortex_compactor_data_disk_class: 'fast',

    // Allow to fine tune compactor.
    cortex_compactor_max_concurrency: 1,
    // While this is the default value, we want to pass the same to the -blocks-storage.bucket-store.sync-interval
    cortex_compactor_cleanup_interval: '15m',

    // Enable use of bucket index by querier, ruler and store-gateway.
    // Bucket index is generated by compactor from Cortex 1.7, there is no flag required to enable this on compactor.
    cortex_bucket_index_enabled: true,
  },

  // We should keep a number of idle connections equal to the max "get" concurrency,
  // in order to avoid re-opening connections continuously (this would be slower
  // and fill up the conntrack table too).
  //
  // The downside of this approach is that we'll end up with an higher number of
  // active connections to memcached, so we have to make sure connections limit
  // set in memcached is high enough.

  blocks_chunks_caching_config::
    (
      if $._config.memcached_index_queries_enabled then {
        'blocks-storage.bucket-store.index-cache.backend': 'memcached',
        'blocks-storage.bucket-store.index-cache.memcached.addresses': 'dnssrvnoa+memcached-index-queries.%(namespace)s.svc.cluster.local:11211' % $._config,
        'blocks-storage.bucket-store.index-cache.memcached.timeout': '200ms',
        'blocks-storage.bucket-store.index-cache.memcached.max-item-size': $._config.memcached_index_queries_max_item_size_mb * 1024 * 1024,
        'blocks-storage.bucket-store.index-cache.memcached.max-async-buffer-size': '25000',
        'blocks-storage.bucket-store.index-cache.memcached.max-async-concurrency': '50',
        'blocks-storage.bucket-store.index-cache.memcached.max-get-multi-batch-size': '100',
        'blocks-storage.bucket-store.index-cache.memcached.max-get-multi-concurrency': 100,
        'blocks-storage.bucket-store.index-cache.memcached.max-idle-connections': self['blocks-storage.bucket-store.index-cache.memcached.max-get-multi-concurrency'],
      } else {}
    ) + (
      if $._config.memcached_chunks_enabled then {
        'blocks-storage.bucket-store.chunks-cache.backend': 'memcached',
        'blocks-storage.bucket-store.chunks-cache.memcached.addresses': 'dnssrvnoa+memcached.%(namespace)s.svc.cluster.local:11211' % $._config,
        'blocks-storage.bucket-store.chunks-cache.memcached.timeout': '200ms',
        'blocks-storage.bucket-store.chunks-cache.memcached.max-item-size': $._config.memcached_chunks_max_item_size_mb * 1024 * 1024,
        'blocks-storage.bucket-store.chunks-cache.memcached.max-async-buffer-size': '25000',
        'blocks-storage.bucket-store.chunks-cache.memcached.max-async-concurrency': '50',
        'blocks-storage.bucket-store.chunks-cache.memcached.max-get-multi-batch-size': '100',
        'blocks-storage.bucket-store.chunks-cache.memcached.max-get-multi-concurrency': 100,
        'blocks-storage.bucket-store.chunks-cache.memcached.max-idle-connections': self['blocks-storage.bucket-store.chunks-cache.memcached.max-get-multi-concurrency'],
      } else {}
    ),

  blocks_metadata_caching_config:: if $._config.memcached_metadata_enabled then {
    'blocks-storage.bucket-store.metadata-cache.backend': 'memcached',
    'blocks-storage.bucket-store.metadata-cache.memcached.addresses': 'dnssrvnoa+memcached-metadata.%(namespace)s.svc.cluster.local:11211' % $._config,
    'blocks-storage.bucket-store.metadata-cache.memcached.timeout': '200ms',
    'blocks-storage.bucket-store.metadata-cache.memcached.max-item-size': $._config.memcached_metadata_max_item_size_mb * 1024 * 1024,
    'blocks-storage.bucket-store.metadata-cache.memcached.max-async-buffer-size': '25000',
    'blocks-storage.bucket-store.metadata-cache.memcached.max-async-concurrency': '50',
    'blocks-storage.bucket-store.metadata-cache.memcached.max-get-multi-batch-size': '100',
    'blocks-storage.bucket-store.metadata-cache.memcached.max-get-multi-concurrency': 100,
    'blocks-storage.bucket-store.metadata-cache.memcached.max-idle-connections': self['blocks-storage.bucket-store.metadata-cache.memcached.max-get-multi-concurrency'],
  } else {},

  bucket_index_config:: if $._config.cortex_bucket_index_enabled then {
    'blocks-storage.bucket-store.bucket-index.enabled': true,

    // Bucket index is updated by compactor on each cleanup cycle.
    'blocks-storage.bucket-store.sync-interval': $._config.cortex_compactor_cleanup_interval,
  } else {},
}
