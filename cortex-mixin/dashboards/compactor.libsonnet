local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  'cortex-compactor.json':
    ($.dashboard('Cortex / Compactor') + { uid: '9c408e1d55681ecb8a22c9fab46875cc' })
    .addClusterSelectorTemplates()
    .addRow(
      $.row('Summary')
      .addPanel(
        $.startedCompletedFailedPanel(
          'Per-instance runs / sec',
          'sum(rate(cortex_compactor_runs_started_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.compactor),
          'sum(rate(cortex_compactor_runs_completed_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.compactor),
          'sum(rate(cortex_compactor_runs_failed_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.compactor)
        ) +
        $.bars +
        $.panelDescription(
          'Per-instance runs',
          |||
            Number of times a compactor instance triggers a compaction across all tenants that it manages.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('Tenants compaction progress') +
        $.queryPanel(|||
          (
            cortex_compactor_tenants_processing_succeeded{%s} +
            cortex_compactor_tenants_processing_failed{%s} +
            cortex_compactor_tenants_skipped{%s}
          ) / cortex_compactor_tenants_discovered{%s}
        ||| % [$.jobMatcher($._config.job_names.compactor), $.jobMatcher($._config.job_names.compactor), $.jobMatcher($._config.job_names.compactor), $.jobMatcher($._config.job_names.compactor)], '{{%s}}' % $._config.per_instance_label) +
        { yaxes: $.yaxes({ format: 'percentunit', max: 1 }) } +
        $.panelDescription(
          'Tenants compaction progress',
          |||
            In a multi-tenant cluster, display the progress of tenants that are compacted while compaction is running.
            Reset to <tt>0</tt> after the compaction run is completed for all tenants in the shard.
          |||
        ),
      )
    )
    .addRow(
      $.row('')
      .addPanel(
        $.timeseriesPanel('Compacted blocks / sec', unit='ops') +
        $.queryPanel('sum(rate(prometheus_tsdb_compactions_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.compactor), 'blocks') +
        $.panelDescription(
          'Compacted blocks / sec',
          |||
            Rate of blocks that are generated as a result of a compaction operation.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('Per-block compaction duration', unit='s') +
        $.latencyPanel('prometheus_tsdb_compaction_duration_seconds', '{%s}' % $.jobMatcher($._config.job_names.compactor)) +
        $.panelDescription(
          'Per-block compaction duration',
          |||
            Display the amount of time that it has taken to generate a single compacted block.
          |||
        ),
      )
    )
    .addRow(
      $.row('')
      .addPanel(
        $.timeseriesPanel('Average blocks / tenant') +
        $.queryPanel('avg(max by(user) (cortex_bucket_blocks_count{%s}))' % $.jobMatcher($._config.job_names.compactor), 'avg'),
      )
      .addPanel(
        $.timeseriesPanel('Tenants with largest number of blocks') +
        $.queryPanel('topk(10, max by(user) (cortex_bucket_blocks_count{%s}))' % $.jobMatcher($._config.job_names.compactor), '{{user}}') +
        $.panelDescription(
          'Tenants with largest number of blocks',
          |||
            The 10 tenants with the largest number of blocks.
          |||
        ),
      )
    )
    .addRow(
      $.row('Garbage Collector')
      .addPanel(
        $.timeseriesPanel('Blocks marked for deletion / sec', unit='ops') +
        $.queryPanel('sum(rate(cortex_compactor_blocks_marked_for_deletion_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.compactor), 'blocks'),
      )
      .addPanel(
        $.successFailurePanel(
          'Blocks deletions / sec',
          // The cortex_compactor_blocks_cleaned_total tracks the number of successfully
          // deleted blocks.
          'sum(rate(cortex_compactor_blocks_cleaned_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.compactor),
          'sum(rate(cortex_compactor_block_cleanup_failures_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.compactor),
        ) + { yaxes: $.yaxes('ops') }
      )
    )
    .addRow(
      $.row('Metadata Sync')
      .addPanel(
        $.successFailurePanel(
          'Metadata Syncs / sec',
          // The cortex_compactor_meta_syncs_total metric is incremented each time a per-tenant
          // metadata sync is triggered.
          'sum(rate(cortex_compactor_meta_syncs_total{%s}[$__rate_interval])) - sum(rate(cortex_compactor_meta_sync_failures_total{%s}[$__rate_interval]))' % [$.jobMatcher($._config.job_names.compactor), $.jobMatcher($._config.job_names.compactor)],
          'sum(rate(cortex_compactor_meta_sync_failures_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.compactor),
        ) + { yaxes: $.yaxes('ops') }
      )
      .addPanel(
        $.timeseriesPanel('Metadata Sync Duration', unit='ms') +
        // This metric tracks the duration of a per-tenant metadata sync.
        $.latencyPanel('cortex_compactor_meta_sync_duration_seconds', '{%s}' % $.jobMatcher($._config.job_names.compactor)),
      )
    )
    .addRows($.getObjectStoreRows('Object Store', 'compactor')),
}
