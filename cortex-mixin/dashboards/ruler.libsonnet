local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  local ruler_config_api_routes_re = 'api_prom_rules.*|api_prom_api_v1_(rules|alerts)',

  rulerQueries+:: {
    ruleEvaluations: {
      success:
        |||
          sum(rate(cortex_prometheus_rule_evaluations_total{%s}[$__rate_interval]))
          -
          sum(rate(cortex_prometheus_rule_evaluation_failures_total{%s}[$__rate_interval]))
        |||,
      failure: 'sum(rate(cortex_prometheus_rule_evaluation_failures_total{%s}[$__rate_interval]))',
      latency:
        |||
          sum (rate(cortex_prometheus_rule_evaluation_duration_seconds_sum{%s}[$__rate_interval]))
            /
          sum (rate(cortex_prometheus_rule_evaluation_duration_seconds_count{%s}[$__rate_interval]))
        |||,
    },
    perUserPerGroupEvaluations: {
      failure: 'sum by(rule_group) (rate(cortex_prometheus_rule_evaluation_failures_total{%s}[$__rate_interval])) > 0',
      latency:
        |||
          sum by(user) (rate(cortex_prometheus_rule_evaluation_duration_seconds_sum{%s}[$__rate_interval]))
            /
          sum by(user) (rate(cortex_prometheus_rule_evaluation_duration_seconds_count{%s}[$__rate_interval]))
        |||,
    },
    groupEvaluations: {
      missedIterations: 'sum by(user) (rate(cortex_prometheus_rule_group_iterations_missed_total{%s}[$__rate_interval])) > 0',
      latency:
        |||
          rate(cortex_prometheus_rule_group_duration_seconds_sum{%s}[$__rate_interval])
            /
          rate(cortex_prometheus_rule_group_duration_seconds_count{%s}[$__rate_interval])
        |||,
    },
    notifications: {
      failure:
        |||
          sum by(user) (rate(cortex_prometheus_notifications_errors_total{%s}[$__rate_interval]))
            /
          sum by(user) (rate(cortex_prometheus_notifications_sent_total{%s}[$__rate_interval]))
          > 0
        |||,
      queue:
        |||
          sum by(user) (rate(cortex_prometheus_notifications_queue_length{%s}[$__rate_interval]))
            /
          sum by(user) (rate(cortex_prometheus_notifications_queue_capacity{%s}[$__rate_interval])) > 0
        |||,
      dropped:
        |||
          sum by (user) (increase(cortex_prometheus_notifications_dropped_total{%s}[$__rate_interval])) > 0
        |||,
    },
  },

  'ruler.json':
    ($.dashboard('Cortex / Ruler') + { uid: '44d12bcb1f95661c6ab6bc946dfc3473' })
    .addClusterSelectorTemplates()
    .addRow(
      ($.row('Headlines') + {
         height: '100px',
         showTitle: false,
       })
      .addPanel(
        $.timeseriesPanel('Active Configurations') +
        $.statPanel('sum(cortex_ruler_managers_total{%s})' % $.jobMatcher($._config.job_names.ruler), format='short')
      )
      .addPanel(
        $.timeseriesPanel('Total Rules') +
        $.statPanel('sum(cortex_prometheus_rule_group_rules{%s})' % $.jobMatcher($._config.job_names.ruler), format='short')
      )
      .addPanel(
        $.timeseriesPanel('Read from Ingesters - QPS') +
        $.statPanel('sum(rate(cortex_ingester_client_request_duration_seconds_count{%s, operation="/cortex.Ingester/QueryStream"}[5m]))' % $.jobMatcher($._config.job_names.ruler), format='reqps')
      )
      .addPanel(
        $.timeseriesPanel('Write to Ingesters - QPS') +
        $.statPanel('sum(rate(cortex_ingester_client_request_duration_seconds_count{%s, operation="/cortex.Ingester/Push"}[5m]))' % $.jobMatcher($._config.job_names.ruler), format='reqps')
      )
    )
    .addRow(
      $.row('Rule Evaluations Global')
      .addPanel(
        $.timeseriesPanel('EPS') +
        $.queryPanel(
          [
            $.rulerQueries.ruleEvaluations.success % [$.jobMatcher($._config.job_names.ruler), $.jobMatcher($._config.job_names.ruler)],
            $.rulerQueries.ruleEvaluations.failure % $.jobMatcher($._config.job_names.ruler),
          ],
          ['success', 'failed'],
        ),
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='s') +
        $.queryPanel(
          $.rulerQueries.ruleEvaluations.latency % [$.jobMatcher($._config.job_names.ruler), $.jobMatcher($._config.job_names.ruler)],
          'average'
        ),
      )
    )
    .addRow(
      $.row('Configuration API (gateway)')
      .addPanel(
        $.timeseriesPanel('QPS') +
        $.qpsPanel('cortex_request_duration_seconds_count{%s, route=~"%s"}' % [$.jobMatcher($._config.job_names.gateway), ruler_config_api_routes_re])
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        utils.latencyRecordingRulePanel('cortex_request_duration_seconds', $.jobSelector($._config.job_names.gateway) + [utils.selector.re('route', ruler_config_api_routes_re)])
      )
      .addPanel(
        $.timeseriesPanel('Per route p99 latency', unit='s') +
        $.queryPanel(
          'histogram_quantile(0.99, sum by (route, le) (cluster_job_route:cortex_request_duration_seconds_bucket:sum_rate{%s, route=~"%s"}))' % [$.jobMatcher($._config.job_names.gateway), ruler_config_api_routes_re],
          '{{ route }}'
        )
      )
    )
    .addRow(
      $.row('Writes (Ingesters)')
      .addPanel(
        $.timeseriesPanel('QPS') +
        $.qpsPanel('cortex_ingester_client_request_duration_seconds_count{%s, operation="/cortex.Ingester/Push"}' % $.jobMatcher($._config.job_names.ruler))
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        $.latencyPanel('cortex_ingester_client_request_duration_seconds', '{%s, operation="/cortex.Ingester/Push"}' % $.jobMatcher($._config.job_names.ruler))
      )
    )
    .addRow(
      $.row('Reads (Ingesters)')
      .addPanel(
        $.timeseriesPanel('QPS') +
        $.qpsPanel('cortex_ingester_client_request_duration_seconds_count{%s, operation="/cortex.Ingester/QueryStream"}' % $.jobMatcher($._config.job_names.ruler))
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        $.latencyPanel('cortex_ingester_client_request_duration_seconds', '{%s, operation="/cortex.Ingester/QueryStream"}' % $.jobMatcher($._config.job_names.ruler))
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('Ruler - Blocks storage')
      .addPanel(
        $.timeseriesPanel('Number of store-gateways hit per Query', unit='short') +
        $.latencyPanel('cortex_querier_storegateway_instances_hit_per_query', '{%s}' % $.jobMatcher($._config.job_names.ruler), multiplier=1),
      )
      .addPanel(
        $.timeseriesPanel('Refetches of missing blocks per Query', unit='short') +
        $.latencyPanel('cortex_querier_storegateway_refetches_per_query', '{%s}' % $.jobMatcher($._config.job_names.ruler), multiplier=1),
      )
      .addPanel(
        $.timeseriesPanel('Consistency checks failed') +
        $.queryPanel('sum(rate(cortex_querier_blocks_consistency_checks_failed_total{%s}[1m])) / sum(rate(cortex_querier_blocks_consistency_checks_total{%s}[1m]))' % [$.jobMatcher($._config.job_names.ruler), $.jobMatcher($._config.job_names.ruler)], 'Failure Rate') +
        { yaxes: $.yaxes({ format: 'percentunit', max: 1 }) },
      )
    )
    .addRow(
      $.row('Notifications')
      .addPanel(
        $.timeseriesPanel('Delivery Errors') +
        $.queryPanel($.rulerQueries.notifications.failure % [$.jobMatcher($._config.job_names.ruler), $.jobMatcher($._config.job_names.ruler)], '{{ user }}')
      )
      .addPanel(
        $.timeseriesPanel('Queue Length') +
        $.queryPanel($.rulerQueries.notifications.queue % [$.jobMatcher($._config.job_names.ruler), $.jobMatcher($._config.job_names.ruler)], '{{ user }}')
      )
      .addPanel(
        $.timeseriesPanel('Dropped') +
        $.queryPanel($.rulerQueries.notifications.dropped % $.jobMatcher($._config.job_names.ruler), '{{ user }}')
      )
    )
    .addRow(
      ($.row('Group Evaluations') + { collapse: true })
      .addPanel(
        $.timeseriesPanel('Missed Iterations') +
        $.queryPanel($.rulerQueries.groupEvaluations.missedIterations % $.jobMatcher($._config.job_names.ruler), '{{ user }}'),
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='s') +
        $.queryPanel(
          $.rulerQueries.groupEvaluations.latency % [$.jobMatcher($._config.job_names.ruler), $.jobMatcher($._config.job_names.ruler)],
          '{{ user }}'
        ),
      )
      .addPanel(
        $.timeseriesPanel('Failures') +
        $.queryPanel(
          $.rulerQueries.perUserPerGroupEvaluations.failure % [$.jobMatcher($._config.job_names.ruler)], '{{ rule_group }}'
        )
      )
    )
    .addRow(
      ($.row('Rule Evaluation per User') + { collapse: true })
      .addPanel(
        $.timeseriesPanel('Latency', unit='s') +
        $.queryPanel(
          $.rulerQueries.perUserPerGroupEvaluations.latency % [$.jobMatcher($._config.job_names.ruler), $.jobMatcher($._config.job_names.ruler)],
          '{{ user }}'
        )
      )
    )
    .addRows(
      $.getObjectStoreRows('Ruler Configuration Object Store (Ruler accesses)', 'ruler-storage')
    ),
}
