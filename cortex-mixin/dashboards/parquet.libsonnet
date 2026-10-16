local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  // Shows the parquet pipeline end to end: the parquet converter turns TSDB blocks into
  // parquet files, the compactor reports how many blocks are converted, and the queriers
  // and rulers read the parquet files through the parquet queryable.
  local queryableRows(title, jobName) = [
    $.row(title)
    .addPanel(
      $.timeseriesPanel('Blocks queried / sec', unit='ops') +
      $.queryPanel('sum by(type) (rate(cortex_parquet_queryable_blocks_queried_total{%s}[$__rate_interval]))' % $.jobMatcher(jobName), '{{type}}') +
      $.stack +
      $.panelDescription(
        'Blocks queried / sec',
        |||
          Rate of blocks found to query, by the format that served them.
          <tt>tsdb</tt> blocks have no parquet files yet and are read from the store-gateways.
        |||
      ),
    )
    .addPanel(
      $.timeseriesPanel('Operations / sec', unit='ops') +
      $.queryPanel('sum by(type, method) (rate(cortex_parquet_queryable_operations_total{%s}[$__rate_interval]))' % $.jobMatcher(jobName), '{{method}} {{type}}') +
      $.stack +
      $.panelDescription(
        'Operations / sec',
        |||
          Rate of Select, LabelNames and LabelValues operations, by the blocks they read.
          <tt>parquet</tt> reads only parquet blocks, <tt>tsdb</tt> only TSDB blocks, and <tt>mixed</tt> both.
        |||
      ),
    )
    .addPanel(
      $.timeseriesPanel('Shard cache hit ratio', unit='percentunit') +
      $.queryPanel(
        |||
          sum(rate(cortex_parquet_cache_hits_total{%s}[$__rate_interval]))
          /
          (
            sum(rate(cortex_parquet_cache_hits_total{%s}[$__rate_interval]))
            +
            sum(rate(cortex_parquet_cache_misses_total{%s}[$__rate_interval]))
          )
        ||| % [$.jobMatcher(jobName), $.jobMatcher(jobName), $.jobMatcher(jobName)],
        'hit ratio'
      ) +
      { yaxes: $.yaxes({ format: 'percentunit', max: 1 }) },
    )
    .addPanel(
      $.timeseriesPanel('Shard cache items') +
      $.queryPanel('sum by(%s) (cortex_parquet_cache_item_count{%s})' % [$._config.per_instance_label, $.jobMatcher(jobName)], '{{%s}}' % $._config.per_instance_label),
    ),
  ],

  'cortex-parquet.json':
    ($.dashboard('Cortex / Parquet') + { uid: 'dfef97d2b024dfd26ee9968cc0a095b9' })
    .addClusterSelectorTemplates()
    .addRow(
      $.row('Converter')
      .addPanel(
        $.successFailurePanel(
          'Block conversions / sec',
          'sum(rate(cortex_parquet_converter_blocks_converted_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.parquet_converter),
          'sum(rate(cortex_parquet_converter_block_convert_failures_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.parquet_converter),
        ) +
        { yaxes: $.yaxes('ops') } +
        $.panelDescription(
          'Block conversions / sec',
          |||
            Rate of TSDB blocks converted to parquet, and of conversions that failed.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('Tenants owned') +
        $.queryPanel('sum by(%s) (cortex_parquet_converter_users_owned{%s})' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.parquet_converter)], '{{%s}}' % $._config.per_instance_label) +
        $.panelDescription(
          'Tenants owned',
          |||
            Number of tenants that each parquet converter instance owns in the ring.
          |||
        ),
      )
    )
    .addRow(
      $.row('')
      .addPanel(
        $.timeseriesPanel('Conversion delay', unit='m') +
        $.latencyPanel('cortex_parquet_converter_convert_block_delay_minutes', '{%s}' % $.jobMatcher($._config.job_names.parquet_converter), multiplier='1') +
        $.panelDescription(
          'Conversion delay',
          |||
            Time from the upload of a TSDB block to object storage until its parquet files are written.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('Latest block conversion duration', unit='s') +
        $.queryPanel('topk(10, max by(user) (cortex_parquet_converter_convert_block_duration_seconds{%s}))' % $.jobMatcher($._config.job_names.parquet_converter), '{{user}}') +
        $.panelDescription(
          'Latest block conversion duration',
          |||
            Time that the latest block conversion took, for the 10 tenants with the slowest one.
          |||
        ),
      )
    )
    .addRow(
      $.row('Bucket')
      .addPanel(
        $.timeseriesPanel('Tenants with largest number of unconverted blocks') +
        $.queryPanel('topk(10, max by(user) (cortex_bucket_parquet_unconverted_blocks_count{%s}))' % $.jobMatcher($._config.job_names.compactor), '{{user}}') +
        $.panelDescription(
          'Tenants with largest number of unconverted blocks',
          |||
            The 10 tenants with the most blocks that are due for conversion but have no parquet files yet.
            The compactor reports this value, so it only updates when the compactor cleans the tenant's bucket.
          |||
        ),
      )
      .addPanel(
        $.timeseriesPanel('Tenants with largest number of parquet blocks') +
        $.queryPanel('topk(10, max by(user) (cortex_bucket_parquet_blocks_count{%s}))' % $.jobMatcher($._config.job_names.compactor), '{{user}}') +
        $.panelDescription(
          'Tenants with largest number of parquet blocks',
          |||
            The 10 tenants with the most parquet blocks in the bucket.
          |||
        ),
      )
    )
    .addRows(queryableRows('Querier', $._config.job_names.querier))
    .addRows(queryableRows('Ruler', $._config.job_names.ruler))
    .addRows($.getObjectStoreRows('Object Store', 'parquet-converter')),
}
