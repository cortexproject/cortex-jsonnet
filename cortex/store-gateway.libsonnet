{
  local container = $.core.v1.container,
  local envType = container.envType,
  local podDisruptionBudget = $.policy.v1.podDisruptionBudget,
  local pvc = $.core.v1.persistentVolumeClaim,
  local statefulSet = $.apps.v1.statefulSet,
  local volumeMount = $.core.v1.volumeMount,

  // The store-gateway runs a statefulset.
  local store_gateway_data_pvc =
    pvc.new() +
    pvc.mixin.spec.resources.withRequests({ storage: $._config.cortex_store_gateway_data_disk_size }) +
    pvc.mixin.spec.withAccessModes(['ReadWriteOnce']) +
    pvc.mixin.spec.withStorageClassName($._config.cortex_store_gateway_data_disk_class) +
    pvc.mixin.metadata.withName('store-gateway-data'),

  store_gateway_args::
    $._config.grpcConfig +
    $._config.blocksStorageConfig +
    $._config.queryBlocksStorageConfig +
    {
      target: 'store-gateway',
      'runtime-config.file': '/etc/cortex/overrides.yaml',

      // Persist ring tokens so that when the store-gateway will be restarted
      // it will pick the same tokens
      'store-gateway.sharding-ring.tokens-file-path': '/data/tokens',

      // Block index-headers are pre-downloaded but lazy mmaped and loaded at query time.
      'blocks-storage.bucket-store.index-header-lazy-loading-enabled': 'true',
      'blocks-storage.bucket-store.index-header-lazy-loading-idle-timeout': '60m',
      'blocks-storage.bucket-store.max-chunk-pool-bytes': 12 * 1024 * 1024 * 1024,
    } +
    $.blocks_chunks_caching_config +
    $.blocks_metadata_caching_config +
    $.bucket_index_config,

  store_gateway_ports:: $.util.defaultPorts,

  store_gateway_container::
    container.new('store-gateway', $._images.store_gateway) +
    container.withPorts($.store_gateway_ports) +
    container.withArgsMixin($.util.mapToFlags($.store_gateway_args)) +
    container.withEnvMap($.store_gateway_env_map) +
    $.go_container_mixin +
    container.withVolumeMountsMixin([volumeMount.new('store-gateway-data', '/data')]) +
    $.util.resourcesRequests('2', '12Gi') +
    $.util.resourcesLimits(null, '18Gi') +
    $.util.readinessProbe +
    $.jaeger_mixin,

  store_gateway_env_map:: {
  },

  newStoreGatewayStatefulSet(name, container)::
    statefulSet.new(name, 3, [container], store_gateway_data_pvc) +
    statefulSet.mixin.spec.withServiceName(name) +
    statefulSet.mixin.metadata.withNamespace($._config.namespace) +
    statefulSet.mixin.metadata.withLabels({ name: name }) +
    statefulSet.mixin.spec.template.metadata.withLabels({ name: name }) +
    statefulSet.mixin.spec.selector.withMatchLabels({ name: name }) +
    statefulSet.mixin.spec.template.spec.securityContext.withRunAsUser(0) +
    statefulSet.mixin.spec.updateStrategy.withType('RollingUpdate') +
    statefulSet.mixin.spec.template.spec.withTerminationGracePeriodSeconds(120) +
    // Parallelly scale up/down store-gateway instances instead of starting them
    // one by one. This does NOT affect rolling updates: they will continue to be
    // rolled out one by one (the next pod will be rolled out once the previous is
    // ready).
    statefulSet.mixin.spec.withPodManagementPolicy('Parallel') +
    $.util.configVolumeMount($._config.overrides_configmap, '/etc/cortex'),

  store_gateway_statefulset: self.newStoreGatewayStatefulSet('store-gateway', $.store_gateway_container),

  store_gateway_service:
    $.util.serviceFor($.store_gateway_statefulset),

  store_gateway_pdb:
    podDisruptionBudget.new('store-gateway-pdb') +
    podDisruptionBudget.mixin.metadata.withLabels({ name: 'store-gateway-pdb' }) +
    podDisruptionBudget.mixin.spec.selector.withMatchLabels({ name: 'store-gateway' }) +
    // To avoid any disruption in the read path we need at least 1 replica of each
    // block available, so the disruption budget depends on the blocks replication factor.
    podDisruptionBudget.mixin.spec.withMaxUnavailable(if $._config.store_gateway_replication_factor > 1 then $._config.store_gateway_replication_factor - 1 else 1),
}
