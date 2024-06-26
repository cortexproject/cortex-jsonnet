(import 'ksonnet-util/kausal.libsonnet') +
(import 'jaeger-agent-mixin/jaeger.libsonnet') +
(import 'images.libsonnet') +
(import 'common.libsonnet') +
(import 'config.libsonnet') +
(import 'tsdb-config.libsonnet') +
(import 'consul.libsonnet') +

// Cortex services
(import 'distributor.libsonnet') +
(import 'ingester.libsonnet') +
(import 'querier.libsonnet') +
(import 'query-frontend.libsonnet') +
(import 'ruler.libsonnet') +
(import 'alertmanager.libsonnet') +
(import 'query-scheduler.libsonnet') +
(import 'compactor.libsonnet') +
(import 'store-gateway.libsonnet') +

// Supporting services
(import 'etcd.libsonnet') +
(import 'memcached.libsonnet') +
(import 'test-exporter.libsonnet')
