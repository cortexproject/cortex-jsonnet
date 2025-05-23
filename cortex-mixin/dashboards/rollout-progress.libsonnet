local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  local config = {
    namespace_matcher: $.namespaceMatcher(),
    gateway_job_matcher: $.jobMatcher($._config.job_names.gateway),
    gateway_write_routes_regex: 'api_(v1|prom)_push',
    gateway_read_routes_regex: '(prometheus|api_prom)_api_v1_.+',
    all_services_regex: std.join('|', ['cortex-gw', 'distributor', 'ingester.*', 'query-frontend.*', 'query-scheduler.*', 'querier.*', 'compactor', 'store-gateway', 'ruler', 'alertmanager']),
  },

  'cortex-rollout-progress.json':
    ($.dashboard('Cortex / Rollout progress') + { uid: '7544a3a62b1be6ffd919fc990ab8ba8f' })
    .addClusterSelectorTemplates(false) + {
      // This dashboard uses the new grid system in order to place panels (using gridPos).
      // Because of this we can't use the mixin's addRow() and addPanel().
      schemaVersion: 27,
      rows: null,
      panels: [
        //
        // Rollout progress
        //
        $.timeseriesPanel('Rollout progress') +
        $.barGauge([
          // Multi-zone deployments are grouped together removing the "zone-X" suffix.
          // After the grouping, the resulting label is called "cortex_service".
          |||
            (
              sum by(cortex_service) (
                label_replace(
                  kube_statefulset_status_replicas_updated{%(namespace_matcher)s,statefulset=~"%(all_services_regex)s"},
                  "cortex_service", "$1", "statefulset", "(.*?)(?:-zone-[a-z])?"
                )
              )
              /
              sum by(cortex_service) (
                label_replace(
                  kube_statefulset_replicas{%(namespace_matcher)s},
                  "cortex_service", "$1", "statefulset", "(.*?)(?:-zone-[a-z])?"
                )
              )
            ) and (
              sum by(cortex_service) (
                label_replace(
                  kube_statefulset_replicas{%(namespace_matcher)s},
                  "cortex_service", "$1", "statefulset", "(.*?)(?:-zone-[a-z])?"
                )
              )
              > 0
            )
          ||| % config,
          |||
            (
              sum by(cortex_service) (
                label_replace(
                  kube_deployment_status_replicas_updated{%(namespace_matcher)s,deployment=~"%(all_services_regex)s"},
                  "cortex_service", "$1", "deployment", "(.*?)(?:-zone-[a-z])?"
                )
              )
              /
              sum by(cortex_service) (
                label_replace(
                  kube_deployment_spec_replicas{%(namespace_matcher)s},
                  "cortex_service", "$1", "deployment", "(.*?)(?:-zone-[a-z])?"
                )
              )
            ) and (
              sum by(cortex_service) (
                label_replace(
                  kube_deployment_spec_replicas{%(namespace_matcher)s},
                  "cortex_service", "$1", "deployment", "(.*?)(?:-zone-[a-z])?"
                )
              )
              > 0
            )
          ||| % config,
        ], legends=[
          '{{cortex_service}}',
          '{{cortex_service}}',
        ], thresholds=[
          { color: 'yellow', value: null },
          { color: 'yellow', value: 0.999 },
          { color: 'green', value: 1 },
        ], unit='percentunit', min=0, max=1) + {
          id: 1,
          gridPos: { h: 8, w: 10, x: 0, y: 0 },
        },

        //
        // Writes
        //
        $.timeseriesPanel('Writes - 2xx') +
        $.newStatPanel(|||
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_write_routes_regex)s",status_code=~"2.+"}[$__rate_interval])) /
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_write_routes_regex)s"}[$__rate_interval]))
        ||| % config, thresholds=[
          { color: 'green', value: null },
        ]) + {
          id: 2,
          gridPos: { h: 4, w: 2, x: 10, y: 0 },
        },

        $.timeseriesPanel('Writes - 4xx') +
        $.newStatPanel(|||
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_write_routes_regex)s",status_code=~"4.+"}[$__rate_interval])) /
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_write_routes_regex)s"}[$__rate_interval]))
        ||| % config, thresholds=[
          { color: 'green', value: null },
          { color: 'orange', value: 0.2 },
          { color: 'red', value: 0.5 },
        ]) + {
          id: 3,
          gridPos: { h: 4, w: 2, x: 12, y: 0 },
        },

        $.timeseriesPanel('Writes - 5xx') +
        $.newStatPanel(|||
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_write_routes_regex)s",status_code=~"5.+"}[$__rate_interval])) /
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_write_routes_regex)s"}[$__rate_interval]))
        ||| % config, thresholds=[
          { color: 'green', value: null },
          { color: 'red', value: 0.01 },
        ]) + {
          id: 4,
          gridPos: { h: 4, w: 2, x: 14, y: 0 },
        },

        $.timeseriesPanel('Writes 99th latency', unit='s') +
        $.newStatPanel(|||
          histogram_quantile(0.99, sum by (le) (cluster_job_route:cortex_request_duration_seconds_bucket:sum_rate{%(gateway_job_matcher)s, route=~"%(gateway_write_routes_regex)s"}))
        ||| % config, unit='s', thresholds=[
          { color: 'green', value: null },
          { color: 'orange', value: 0.2 },
          { color: 'red', value: 0.5 },
        ]) + {
          id: 5,
          gridPos: { h: 4, w: 8, x: 16, y: 0 },
        },

        //
        // Reads
        //
        $.timeseriesPanel('Reads - 2xx') +
        $.newStatPanel(|||
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_read_routes_regex)s",status_code=~"2.+"}[$__rate_interval])) /
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_read_routes_regex)s"}[$__rate_interval]))
        ||| % config, thresholds=[
          { color: 'green', value: null },
        ]) + {
          id: 6,
          gridPos: { h: 4, w: 2, x: 10, y: 4 },
        },

        $.timeseriesPanel('Reads - 4xx') +
        $.newStatPanel(|||
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_read_routes_regex)s",status_code=~"4.+"}[$__rate_interval])) /
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_read_routes_regex)s"}[$__rate_interval]))
        ||| % config, thresholds=[
          { color: 'green', value: null },
          { color: 'orange', value: 0.01 },
          { color: 'red', value: 0.05 },
        ]) + {
          id: 7,
          gridPos: { h: 4, w: 2, x: 12, y: 4 },
        },

        $.timeseriesPanel('Reads - 5xx') +
        $.newStatPanel(|||
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_read_routes_regex)s",status_code=~"5.+"}[$__rate_interval])) /
          sum(rate(cortex_request_duration_seconds_count{%(gateway_job_matcher)s, route=~"%(gateway_read_routes_regex)s"}[$__rate_interval]))
        ||| % config, thresholds=[
          { color: 'green', value: null },
          { color: 'red', value: 0.01 },
        ]) + {
          id: 8,
          gridPos: { h: 4, w: 2, x: 14, y: 4 },
        },

        $.timeseriesPanel('Reads 99th latency', unit='s') +
        $.newStatPanel(|||
          histogram_quantile(0.99, sum by (le) (cluster_job_route:cortex_request_duration_seconds_bucket:sum_rate{%(gateway_job_matcher)s, route=~"%(gateway_read_routes_regex)s"}))
        ||| % config, unit='s', thresholds=[
          { color: 'green', value: null },
          { color: 'orange', value: 1 },
          { color: 'red', value: 2.5 },
        ]) + {
          id: 9,
          gridPos: { h: 4, w: 8, x: 16, y: 4 },
        },

        //
        // Unhealthy pods
        //
        $.timeseriesPanel('Unhealthy pods') +
        $.newStatPanel([
          |||
            kube_deployment_status_replicas_unavailable{%(namespace_matcher)s, deployment=~"%(all_services_regex)s"}
            > 0
          ||| % config,
          |||
            kube_statefulset_status_replicas_current{%(namespace_matcher)s, statefulset=~"%(all_services_regex)s"} -
            kube_statefulset_status_replicas_ready {%(namespace_matcher)s, statefulset=~"%(all_services_regex)s"}
            > 0
          ||| % config,
        ], legends=[
          '{{deployment}}',
          '{{statefulset}}',
        ], thresholds=[
          { color: 'green', value: null },
          { color: 'orange', value: 1 },
          { color: 'red', value: 2 },
        ], instant=true, novalue='All healthy', unit='short', decimals=0) + {
          options: {
            text: {
              // Small font size since we may have many entries during a rollout.
              titleSize: 14,
              valueSize: 14,
            },
          },
          id: 10,
          gridPos: { h: 8, w: 10, x: 0, y: 8 },
        },

        //
        // Versions
        //
        {
          title: 'Pods count per Version',
          type: 'table',
          datasource: '$datasource',

          targets: [
            {
              expr: |||
                count by(container, version) (
                  label_replace(
                    kube_pod_container_info{%(namespace_matcher)s,container=~"%(all_services_regex)s"},
                    "version", "$1", "image", ".*:(.+)-.*"
                  )
                )
              ||| % config,
              instant: true,
              legendFormat: '',
              refId: 'A',
            },
          ],

          fieldConfig: {
            overrides: [
              {
                // Center align the version.
                matcher: { id: 'byRegexp', options: 'r.*' },
                properties: [{ id: 'custom.align', value: 'center' }],
              },
            ],
          },

          transformations: [
            {
              // Transform the version label to a field.
              id: 'labelsToFields',
              options: { valueLabel: 'version' },
            },
            {
              // Hide time.
              id: 'organize',
              options: { excludeByName: { Time: true } },
            },
            {
              // Sort by container.
              id: 'sortBy',
              options: { fields: {}, sort: [{ field: 'container' }] },
            },
          ],

          id: 11,
          gridPos: { h: 8, w: 6, x: 10, y: 8 },
        },

        //
        // Performance comparison with 24h ago
        //
        $.timeseriesPanel('Latency vs 24h ago') +
        $.queryPanel([|||
          1 - (
            avg_over_time(histogram_quantile(0.99, sum by (le) (cluster_job_route:cortex_request_duration_seconds_bucket:sum_rate{%(gateway_job_matcher)s, route=~"%(gateway_write_routes_regex)s"} offset 24h))[1h:])
            /
            avg_over_time(histogram_quantile(0.99, sum by (le) (cluster_job_route:cortex_request_duration_seconds_bucket:sum_rate{%(gateway_job_matcher)s, route=~"%(gateway_write_routes_regex)s"}))[1h:])
          )
        ||| % config, |||
          1 - (
            avg_over_time(histogram_quantile(0.99, sum by (le) (cluster_job_route:cortex_request_duration_seconds_bucket:sum_rate{%(gateway_job_matcher)s, route=~"%(gateway_read_routes_regex)s"} offset 24h))[1h:])
            /
            avg_over_time(histogram_quantile(0.99, sum by (le) (cluster_job_route:cortex_request_duration_seconds_bucket:sum_rate{%(gateway_job_matcher)s, route=~"%(gateway_read_routes_regex)s"}))[1h:])
          )
        ||| % config], ['writes', 'reads']) + {
          yaxes: $.yaxes({
            format: 'percentunit',
            min: null,  // Can be negative.
          }),

          id: 12,
          gridPos: { h: 8, w: 8, x: 16, y: 8 },
        },
      ],

      templating+: {
        list: [
          // Do not allow to include all clusters/namespaces cause this dashboard is designed to show
          // 1 cluster at a time.
          l + (if (l.name == 'cluster' || l.name == 'namespace') then { includeAll: false } else {})
          for l in super.list
        ],
      },
    },
}
