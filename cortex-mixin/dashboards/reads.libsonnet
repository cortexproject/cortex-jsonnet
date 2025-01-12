local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  'cortex-reads.json':
    ($.dashboard('Cortex / Reads') + { uid: '8d6ba60eccc4b6eedfa329b24b1bd339' })
    .addClusterSelectorTemplates()
    .addRowIf(
      $._config.show_dashboard_descriptions.reads,
      ($.row('Reads dashboard description') { height: '175px', showTitle: false })
      .addPanel(
        $.textPanel('', |||
          <p>
            This dashboard shows health metrics for the Cortex read path.
            It is broken into sections for each service on the read path, and organized by the order in which the read request flows.
            <br/>
            Incoming queries travel from the gateway → query frontend → query scheduler → querier → ingester and/or store-gateway (depending on the time range of the query).
            <br/>
            For each service, there are 3 panels showing (1) requests per second to that service, (2) average, median, and p99 latency of requests to that service, and (3) p99 latency of requests to each instance of that service.
          </p>
          <p>
            The dashboard also shows metrics for the 4 optional caches that can be deployed with Cortex:
            the query results cache, the metadata cache, the chunks cache, and the index cache.
            <br/>
            These panels will show “no data” if the caches are not deployed.
          </p>
          <p>
            Lastly, it also includes metrics for how the ingester and store-gateway interact with object storage.
          </p>
        |||),
      )
    )
    .addRow(
      ($.row('Headlines') +
       {
         height: '100px',
         showTitle: false,
       })
      .addPanel(
        $.timeseriesPanel('Instant queries / sec') +
        $.statPanel(|||
          sum(
            rate(
              cortex_request_duration_seconds_count{
                %(queryFrontend)s,
                route=~"(prometheus|api_prom)_api_v1_query"
              }[$__rate_interval]
            )
          ) +
          sum(
            rate(
              cortex_prometheus_rule_evaluations_total{
                %(ruler)s
              }[$__rate_interval]
            )
          )
        ||| % {
          queryFrontend: $.jobMatcher($._config.job_names.query_frontend),
          ruler: $.jobMatcher($._config.job_names.ruler),
        }, format='reqps') +
        $.panelDescription(
          'Instant queries per second',
          |||
            Rate of instant queries per second being made to the system.
            Includes both queries made to the <tt>/prometheus</tt> API as
            well as queries from the ruler.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('Range queries / sec') +
        $.statPanel(|||
          sum(
            rate(
              cortex_request_duration_seconds_count{
                %(queryFrontend)s,
                route=~"(prometheus|api_prom)_api_v1_query_range"
              }[$__rate_interval]
            )
          )
        ||| % {
          queryFrontend: $.jobMatcher($._config.job_names.query_frontend),
        }, format='reqps') +
        $.panelDescription(
          'Range queries per second',
          |||
            Rate of range queries per second being made to
            Cortex via the <tt>/prometheus</tt> API.
          |||
        ),
      )
    )
    .addRow(
      $.row('Gateway')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_request_duration_seconds_count{%s, route=~"(prometheus|api_prom)_api_v1_.+"}' % $.jobMatcher($._config.job_names.gateway))
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        utils.latencyRecordingRulePanel('cortex_request_duration_seconds', $.jobSelector($._config.job_names.gateway) + [utils.selector.re('route', '(prometheus|api_prom)_api_v1_.+')])
      )
      .addPanel(
        $.timeseriesPanel('Per %s p99 Latency' % $._config.per_instance_label, unit='s') +
        $.hiddenLegendQueryPanel(
          'histogram_quantile(0.99, sum by(le, %s) (rate(cortex_request_duration_seconds_bucket{%s, route=~"(prometheus|api_prom)_api_v1_.+"}[$__rate_interval])))' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.gateway)], ''
        )
      )
    )
    .addRow(
      $.row('Query Frontend')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_request_duration_seconds_count{%s, route=~"(prometheus|api_prom)_api_v1_.+"}' % $.jobMatcher($._config.job_names.query_frontend))
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        utils.latencyRecordingRulePanel('cortex_request_duration_seconds', $.jobSelector($._config.job_names.query_frontend) + [utils.selector.re('route', '(prometheus|api_prom)_api_v1_.+')])
      )
      .addPanel(
        $.timeseriesPanel('Per %s p99 Latency' % $._config.per_instance_label, unit='s') +
        $.hiddenLegendQueryPanel(
          'histogram_quantile(0.99, sum by(le, %s) (rate(cortex_request_duration_seconds_bucket{%s, route=~"(prometheus|api_prom)_api_v1_.+"}[$__rate_interval])))' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.query_frontend)], ''
        )
      )
    )
    .addRow(
      $.row('Query Scheduler')
      .addPanel(
        $.textPanel(
          '',
          |||
            <p>
              The query scheduler is an optional service that moves
              the internal queue from the query-frontend into a
              separate component.
              If this service is not deployed,
              these panels will show "No data."
            </p>
          |||
        )
      )
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_query_scheduler_queue_duration_seconds_count{%s}' % $.jobMatcher($._config.job_names.query_scheduler))
      )
      .addPanel(
        $.timeseriesPanel('Latency (Time in Queue)') +
        $.latencyPanel('cortex_query_scheduler_queue_duration_seconds', '{%s}' % $.jobMatcher($._config.job_names.query_scheduler))
      )
    )
    .addRow(
      $.row('Cache - Query Results')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_cache_request_duration_seconds_count{method=~"frontend.+", %s}' % $.jobMatcher($._config.job_names.query_frontend))
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        utils.latencyRecordingRulePanel('cortex_cache_request_duration_seconds', $.jobSelector($._config.job_names.query_frontend) + [utils.selector.re('method', 'frontend.+')])
      )
    )
    .addRow(
      $.row('Querier')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_querier_request_duration_seconds_count{%s, route=~"(prometheus|api_prom)_api_v1_.+"}' % $.jobMatcher($._config.job_names.querier))
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        utils.latencyRecordingRulePanel('cortex_querier_request_duration_seconds', $.jobSelector($._config.job_names.querier) + [utils.selector.re('route', '(prometheus|api_prom)_api_v1_.+')])
      )
      .addPanel(
        $.timeseriesPanel('Per %s p99 Latency' % $._config.per_instance_label, unit='s') +
        $.hiddenLegendQueryPanel(
          'histogram_quantile(0.99, sum by(le, %s) (rate(cortex_querier_request_duration_seconds_bucket{%s, route=~"(prometheus|api_prom)_api_v1_.+"}[$__rate_interval])))' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.querier)], ''
        )
      )
    )
    .addRow(
      $.row('Ingester')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_request_duration_seconds_count{%s,route=~"/cortex.Ingester/Query(Stream)?|/cortex.Ingester/MetricsForLabelMatchers|/cortex.Ingester/LabelValues|/cortex.Ingester/MetricsMetadata"}' % $.jobMatcher($._config.job_names.ingester))
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        utils.latencyRecordingRulePanel('cortex_request_duration_seconds', $.jobSelector($._config.job_names.ingester) + [utils.selector.re('route', '/cortex.Ingester/Query(Stream)?|/cortex.Ingester/MetricsForLabelMatchers|/cortex.Ingester/LabelValues|/cortex.Ingester/MetricsMetadata')])
      )
      .addPanel(
        $.timeseriesPanel('Per %s p99 Latency' % $._config.per_instance_label, unit='s') +
        $.hiddenLegendQueryPanel(
          'histogram_quantile(0.99, sum by(le, %s) (rate(cortex_request_duration_seconds_bucket{%s, route=~"/cortex.Ingester/Query(Stream)?|/cortex.Ingester/MetricsForLabelMatchers|/cortex.Ingester/LabelValues|/cortex.Ingester/MetricsMetadata"}[$__rate_interval])))' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.ingester)], ''
        )
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('Store-gateway')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_request_duration_seconds_count{%s,route=~"/gatewaypb.StoreGateway/.*"}' % $.jobMatcher($._config.job_names.store_gateway))
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        utils.latencyRecordingRulePanel('cortex_request_duration_seconds', $.jobSelector($._config.job_names.store_gateway) + [utils.selector.re('route', '/gatewaypb.StoreGateway/.*')])
      )
      .addPanel(
        $.timeseriesPanel('Per %s p99 Latency' % $._config.per_instance_label, unit='s') +
        $.hiddenLegendQueryPanel(
          'histogram_quantile(0.99, sum by(le, %s) (rate(cortex_request_duration_seconds_bucket{%s, route=~"/gatewaypb.StoreGateway/.*"}[$__rate_interval])))' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.store_gateway)], ''
        )
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('Memcached – Blocks storage – Block index cache (store-gateway accesses)')  // Resembles thanosMemcachedCache
      .addPanel(
        $.timeseriesPanel('Requests / sec', unit='ops') +
        $.queryPanel(
          |||
            sum by(operation) (
              rate(
                thanos_memcached_operations_total{
                  component="store-gateway",
                  name="index-cache",
                  %s
                }[$__rate_interval]
              )
            )
          ||| % $.jobMatcher($._config.job_names.store_gateway), '{{operation}}'
        ) +
        $.stack,
      )
      .addPanel(
        $.timeseriesPanel('Latency (getmulti)') +
        $.latencyPanel(
          'thanos_memcached_operation_duration_seconds',
          |||
            {
              %s,
              operation="getmulti",
              component="store-gateway",
              name="index-cache"
            }
          ||| % $.jobMatcher($._config.job_names.store_gateway)
        )
      )
      .addPanel(
        $.timeseriesPanel('Hit ratio') +
        $.queryPanel(
          |||
            sum by(item_type) (
              rate(
                thanos_store_index_cache_hits_total{
                  component="store-gateway",
                  %s
                }[$__rate_interval]
              )
            )
            /
            sum by(item_type) (
              rate(
                thanos_store_index_cache_requests_total{
                  component="store-gateway",
                  %s
                }[$__rate_interval]
              )
            )
          ||| % [
            $.jobMatcher($._config.job_names.store_gateway),
            $.jobMatcher($._config.job_names.store_gateway),
          ],
          '{{item_type}}'
        ) +
        { yaxes: $.yaxes('percentunit') } +
        $.panelDescription(
          'Hit Ratio',
          |||
            Even if you do not set up memcached for the blocks index cache, you will still see data in this panel because Cortex by default has an
            in-memory blocks index cache.
          |||
        ),
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.thanosMemcachedCache(
        'Memcached – Blocks storage – Chunks cache (store-gateway accesses)',
        $._config.job_names.store_gateway,
        'store-gateway',
        'chunks-cache'
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.thanosMemcachedCache(
        'Memcached – Blocks storage – Metadata cache (store-gateway accesses)',
        $._config.job_names.store_gateway,
        'store-gateway',
        'metadata-cache'
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.thanosMemcachedCache(
        'Memcached – Blocks storage – Metadata cache (querier accesses)',
        $._config.job_names.querier,
        'querier',
        'metadata-cache'
      )
    )
    // Object store metrics for the store-gateway.
    .addRowsIf(
      std.member($._config.storage_engine, 'blocks'),
      $.getObjectStoreRows('Blocks Object Store (Store-gateway accesses)', 'store-gateway')
    )
    // Object store metrics for the querier.
    .addRowsIf(
      std.member($._config.storage_engine, 'blocks'),
      $.getObjectStoreRows('Blocks Object Store  (Querier accesses)', 'querier')
    ),
}
