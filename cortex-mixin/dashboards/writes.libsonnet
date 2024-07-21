local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  'cortex-writes.json':
    ($.dashboard('Cortex / Writes') + { uid: '0156f6d15aa234d452a33a4f13c838e3' })
    .addClusterSelectorTemplates()
    .addRowIf(
      $._config.show_dashboard_descriptions.writes,
      ($.row('Writes dashboard description') { height: '125px', showTitle: false })
      .addPanel(
        $.textPanel('', |||
          <p>
            This dashboard shows various health metrics for the Cortex write path.
            It is broken into sections for each service on the write path,
            and organized by the order in which the write request flows.
            <br/>
            Incoming metrics data travels from the gateway → distributor → ingester.
            <br/>
            For each service, there are 3 panels showing
            (1) requests per second to that service,
            (2) average, median, and p99 latency of requests to that service, and
            (3) p99 latency of requests to each instance of that service.
          </p>
          <p>
            It also includes metrics for the key-value (KV) stores used to manage
            the high-availability tracker and the ingesters.
          </p>
        |||),
      )
    ).addRow(
      ($.row('Headlines') +
       {
         height: '100px',
         showTitle: false,
       })
      .addPanel(
        $.timeseriesPanel('Samples / sec') +
        $.statPanel(
          'sum(%(group_prefix_jobs)s:cortex_distributor_received_samples:rate5m{%(job)s})' % (
            $._config {
              job: $.jobMatcher($._config.job_names.distributor),
            }
          ),
          format='short'
        )
      )
      .addPanel(
        $.timeseriesPanel('Active Series') +
        $.statPanel(|||
          sum(cortex_ingester_memory_series{%(ingester)s}
          / on(%(group_by_cluster)s) group_left
          max by (%(group_by_cluster)s) (cortex_distributor_replication_factor{%(distributor)s}))
        ||| % ($._config) {
          ingester: $.jobMatcher($._config.job_names.ingester),
          distributor: $.jobMatcher($._config.job_names.distributor),
        }, format='short')
      )
      .addPanel(
        $.timeseriesPanel('Tenants') +
        $.statPanel('count(count by(user) (cortex_ingester_active_series{%s}))' % $.jobMatcher($._config.job_names.ingester), format='short')
      )
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.statPanel('sum(rate(cortex_request_duration_seconds_count{%s, route=~"api_(v1|prom)_push"}[5m]))' % $.jobMatcher($._config.job_names.gateway), format='reqps')
      )
    )
    .addRow(
      $.row('Gateway')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_request_duration_seconds_count{%s, route=~"api_(v1|prom)_push"}' % $.jobMatcher($._config.job_names.gateway))
      )
      .addPanel(
        $.timeseriesPanel('Latency') +
        utils.latencyRecordingRulePanel('cortex_request_duration_seconds', $.jobSelector($._config.job_names.gateway) + [utils.selector.re('route', 'api_(v1|prom)_push')])
      )
      .addPanel(
        $.timeseriesPanel('Per %s p99 Latency' % $._config.per_instance_label) +
        $.hiddenLegendQueryPanel(
          'histogram_quantile(0.99, sum by(le, %s) (rate(cortex_request_duration_seconds_bucket{%s, route=~"api_(v1|prom)_push"}[$__rate_interval])))' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.gateway)], ''
        ) +
        { yaxes: $.yaxes('s') }
      )
    )
    .addRow(
      $.row('Distributor')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_request_duration_seconds_count{%s, route=~"/distributor.Distributor/Push|/httpgrpc.*|api_(v1|prom)_push"}' % $.jobMatcher($._config.job_names.distributor))
      )
      .addPanel(
        $.timeseriesPanel('Latency') +
        utils.latencyRecordingRulePanel('cortex_request_duration_seconds', $.jobSelector($._config.job_names.distributor) + [utils.selector.re('route', '/distributor.Distributor/Push|/httpgrpc.*|api_(v1|prom)_push')])
      )
      .addPanel(
        $.timeseriesPanel('Per %s p99 Latency' % $._config.per_instance_label) +
        $.hiddenLegendQueryPanel(
          'histogram_quantile(0.99, sum by(le, %s) (rate(cortex_request_duration_seconds_bucket{%s, route=~"/distributor.Distributor/Push|/httpgrpc.*|api_(v1|prom)_push"}[$__rate_interval])))' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.distributor)], ''
        ) +
        { yaxes: $.yaxes('s') }
      )
    )
    .addRow(
      $.row('Key-value store for high-availability (HA) deduplication')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_kv_request_duration_seconds_count{%s}' % $.jobMatcher($._config.job_names.distributor))
      )
      .addPanel(
        $.timeseriesPanel('Latency') +
        utils.latencyRecordingRulePanel('cortex_kv_request_duration_seconds', $.jobSelector($._config.job_names.distributor))
      )
    )
    .addRow(
      $.row('Ingester')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_request_duration_seconds_count{%s,route="/cortex.Ingester/Push"}' % $.jobMatcher($._config.job_names.ingester))
      )
      .addPanel(
        $.timeseriesPanel('Latency') +
        utils.latencyRecordingRulePanel('cortex_request_duration_seconds', $.jobSelector($._config.job_names.ingester) + [utils.selector.eq('route', '/cortex.Ingester/Push')])
      )
      .addPanel(
        $.timeseriesPanel('Per %s p99 Latency' % $._config.per_instance_label) +
        $.hiddenLegendQueryPanel(
          'histogram_quantile(0.99, sum by(le, %s) (rate(cortex_request_duration_seconds_bucket{%s, route="/cortex.Ingester/Push"}[$__rate_interval])))' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.ingester)], ''
        ) +
        { yaxes: $.yaxes('s') }
      )
    )
    .addRow(
      $.row('Key-value store for the ingesters ring')
      .addPanel(
        $.timeseriesPanel('Requests / sec') +
        $.qpsPanel('cortex_kv_request_duration_seconds_count{%s}' % $.jobMatcher($._config.job_names.ingester))
      )
      .addPanel(
        $.timeseriesPanel('Latency') +
        utils.latencyRecordingRulePanel('cortex_kv_request_duration_seconds', $.jobSelector($._config.job_names.ingester))
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('Ingester - Blocks storage - Shipper')
      .addPanel(
        $.successFailurePanel(
          'Uploaded blocks / sec',
          'sum(rate(cortex_ingester_shipper_uploads_total{%s}[$__rate_interval])) - sum(rate(cortex_ingester_shipper_upload_failures_total{%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.ingester), $.jobMatcher($._config.job_names.ingester)],
          'sum(rate(cortex_ingester_shipper_upload_failures_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.ingester),
        ) +
        $.panelDescription(
          'Uploaded blocks / sec',
          |||
            The rate of blocks being uploaded from the ingesters
            to object storage.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('Upload latency') +
        $.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', '{%s,component="ingester",operation="upload"}' % $.jobMatcher($._config.job_names.ingester)) +
        $.panelDescription(
          'Upload latency',
          |||
            The average, median (50th percentile), and 99th percentile time
            the ingesters take to upload blocks to object storage.
          |||
        ),
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('Ingester - Blocks storage - TSDB Head')
      .addPanel(
        $.successFailurePanel(
          'Compactions / sec',
          'sum(rate(cortex_ingester_tsdb_compactions_total{%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.ingester)],
          'sum(rate(cortex_ingester_tsdb_compactions_failed_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.ingester),
        ) +
        $.panelDescription(
          'Compactions per second',
          |||
            Ingesters maintain a local TSDB per-tenant on disk. Each TSDB maintains a head block for each
            active time series; these blocks get periodically compacted (by default, every 2h).
            This panel shows the rate of compaction operations across all TSDBs on all ingesters.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('Compactions latency') +
        $.latencyPanel('cortex_ingester_tsdb_compaction_duration_seconds', '{%s}' % $.jobMatcher($._config.job_names.ingester)) +
        $.panelDescription(
          'Compaction latency',
          |||
            The average, median (50th percentile), and 99th percentile time ingesters take to compact TSDB head blocks
            on the local filesystem.
          |||
        ),
      )
    )
    .addRowIf(
      std.member($._config.storage_engine, 'blocks'),
      $.row('Ingester - Blocks storage - TSDB write ahead log (WAL)')
      .addPanel(
        $.successFailurePanel(
          'WAL truncations / sec',
          'sum(rate(cortex_ingester_tsdb_wal_truncations_total{%s}[$__rate_interval])) - sum(rate(cortex_ingester_tsdb_wal_truncations_failed_total{%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.ingester), $.jobMatcher($._config.job_names.ingester)],
          'sum(rate(cortex_ingester_tsdb_wal_truncations_failed_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.ingester),
        ) +
        $.panelDescription(
          'WAL truncations per second',
          |||
            The WAL is truncated each time a new TSDB block is written. This panel measures the rate of
            truncations.
          |||
        ),
      )
      .addPanel(
        $.successFailurePanel(
          'Checkpoints created / sec',
          'sum(rate(cortex_ingester_tsdb_checkpoint_creations_total{%s}[$__rate_interval])) - sum(rate(cortex_ingester_tsdb_checkpoint_creations_failed_total{%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.ingester), $.jobMatcher($._config.job_names.ingester)],
          'sum(rate(cortex_ingester_tsdb_checkpoint_creations_failed_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.ingester),
        ) +
        $.panelDescription(
          'Checkpoints created per second',
          |||
            Checkpoints are created as part of the WAL truncation process.
            This metric measures the rate of checkpoint creation.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('WAL truncations latency (includes checkpointing)') +
        $.queryPanel('sum(rate(cortex_ingester_tsdb_wal_truncate_duration_seconds_sum{%s}[$__rate_interval])) / sum(rate(cortex_ingester_tsdb_wal_truncate_duration_seconds_count{%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.ingester), $.jobMatcher($._config.job_names.ingester)], 'avg') +
        { yaxes: $.yaxes('s') } +
        $.panelDescription(
          'WAL truncations latency (including checkpointing)',
          |||
            Average time taken to perform a full WAL truncation,
            including the time taken for the checkpointing to complete.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('Corruptions / sec') +
        $.queryPanel([
          'sum(rate(cortex_ingester_wal_corruptions_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.ingester),
          'sum(rate(cortex_ingester_tsdb_mmap_chunk_corruptions_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.ingester),
        ], [
          'WAL',
          'mmap-ed chunks',
        ]) +
        $.stack + {
          yaxes: $.yaxes('ops'),
          aliasColors: {
            WAL: '#E24D42',
            'mmap-ed chunks': '#E28A42',
          },
        },
      )
    ),
}
