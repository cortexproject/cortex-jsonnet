{
  _images+:: {
    // Various third-party images.
    memcached: 'memcached:1.6.23-alpine',
    memcachedExporter: 'prom/memcached-exporter:v0.14.2',

    // Our services.
    cortex: 'cortexproject/cortex:v1.17.1',

    alertmanager: self.cortex,
    distributor: self.cortex,
    ingester: self.cortex,
    querier: self.cortex,
    query_frontend: self.cortex,
    tableManager: self.cortex,
    compactor: self.cortex,
    flusher: self.cortex,
    ruler: self.cortex,
    store_gateway: self.cortex,
    query_scheduler: self.cortex,

    overrides_exporter: self.cortex,
    query_tee: 'quay.io/cortexproject/query-tee:v1.17.1',
    testExporter: 'cortexproject/test-exporter:v1.17.1',
  },
}
