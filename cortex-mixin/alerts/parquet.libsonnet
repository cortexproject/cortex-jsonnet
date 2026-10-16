{
  groups+: [
    {
      name: 'cortex_parquet_alerts',
      rules: [
        {
          // Alert if the parquet converter fails to convert the blocks of a tenant and
          // converts none of them.
          alert: 'CortexParquetConverterFailingConversions',
          'for': '1h',
          expr: |||
            sum by(%(alert_aggregation_labels)s, user) (increase(cortex_parquet_converter_block_convert_failures_total[1h])) > 0
            unless
            sum by(%(alert_aggregation_labels)s, user) (increase(cortex_parquet_converter_blocks_converted_total[1h])) > 0
          ||| % $._config,
          labels: {
            severity: 'warning',
          },
          annotations: {
            message: |||
              Cortex Parquet Converter in %(alert_aggregation_variables)s fails to convert blocks of tenant {{ $labels.user }} and converted none in the last hour.
            ||| % $._config,
          },
        },
        {
          // Alert if a tenant has blocks that are due for conversion, but the parquet
          // converter has not converted any of its blocks in the last 3h.
          alert: 'CortexParquetConverterNotConverting',
          'for': '3h',
          expr: |||
            max by(%(alert_aggregation_labels)s, user) (cortex_bucket_parquet_unconverted_blocks_count) > 0
            unless
            sum by(%(alert_aggregation_labels)s, user) (increase(cortex_parquet_converter_blocks_converted_total[3h])) > 0
          ||| % $._config,
          labels: {
            severity: 'critical',
          },
          annotations: {
            message: |||
              Tenant {{ $labels.user }} in %(alert_aggregation_variables)s has {{ $value }} blocks that are due for parquet conversion, and the Cortex Parquet Converter converted none in the last 3 hours.
            ||| % $._config,
          },
        },
        {
          // Alert if more than 20% of the conversions finish more than 5h (the top bucket
          // of the histogram) after the TSDB block was uploaded.
          alert: 'CortexParquetConversionDelayHigh',
          'for': '1h',
          expr: |||
            (
              1 - (
                sum by(%(alert_aggregation_labels)s) (rate(cortex_parquet_converter_convert_block_delay_minutes_bucket{le="300"}[3h]))
                /
                sum by(%(alert_aggregation_labels)s) (rate(cortex_parquet_converter_convert_block_delay_minutes_count[3h]))
              )
            ) > 0.2
          ||| % $._config,
          labels: {
            severity: 'warning',
          },
          annotations: {
            message: |||
              More than 20%% of the parquet conversions in %(alert_aggregation_variables)s finish more than 5 hours after the TSDB block was uploaded.
            ||| % $._config,
          },
        },
        {
          // Alert if the parquet converter ring has unhealthy members. The blocks of the
          // tenants that an unhealthy member owns are not converted.
          alert: 'CortexParquetConverterRingUnhealthy',
          'for': '15m',
          expr: |||
            max by(%(alert_aggregation_labels)s) (cortex_ring_members{name="parquet-converter", state="Unhealthy"}) > 0
          ||| % $._config,
          labels: {
            severity: 'warning',
          },
          annotations: {
            message: |||
              The Cortex Parquet Converter ring in %(alert_aggregation_variables)s has {{ $value }} unhealthy members.
            ||| % $._config,
          },
        },
        {
          // Alert if most of the blocks that the parquet queryable finds are TSDB blocks,
          // which are read from the store-gateways in place of the parquet files.
          alert: 'CortexParquetQueryableMostlyTSDB',
          'for': '2h',
          expr: |||
            (
              sum by(%(alert_aggregation_labels)s) (rate(cortex_parquet_queryable_blocks_queried_total{type="tsdb"}[1h]))
              /
              sum by(%(alert_aggregation_labels)s) (rate(cortex_parquet_queryable_blocks_queried_total[1h]))
            ) > 0.7
          ||| % $._config,
          labels: {
            severity: 'warning',
          },
          annotations: {
            message: |||
              More than 70%% of the blocks queried through the parquet queryable in %(alert_aggregation_variables)s are TSDB blocks.
            ||| % $._config,
          },
        },
        {
          // Alert if most of the blocks of a tenant are neither parquet blocks nor due for
          // conversion. The converter only takes blocks wider than the first compactor block
          // range, so this usually means that the compactor cannot compact the tenant past
          // the first range and the parquet converter has nothing to convert.
          alert: 'CortexParquetCompactionStuckAtFirstRange',
          'for': '6h',
          expr: |||
            (
              (
                max by(%(alert_aggregation_labels)s, user) (cortex_bucket_blocks_count)
                - max by(%(alert_aggregation_labels)s, user) (cortex_bucket_parquet_blocks_count)
                - max by(%(alert_aggregation_labels)s, user) (cortex_bucket_parquet_unconverted_blocks_count)
              )
              / max by(%(alert_aggregation_labels)s, user) (cortex_bucket_blocks_count)
            ) > 0.8
            and
            max by(%(alert_aggregation_labels)s, user) (cortex_bucket_blocks_count) > 500
          ||| % $._config,
          labels: {
            severity: 'critical',
          },
          annotations: {
            message: |||
              {{ $value | humanizePercentage }} of the blocks of tenant {{ $labels.user }} in %(alert_aggregation_variables)s are not compacted past the first block range, so the Cortex Parquet Converter has nothing to convert.
            ||| % $._config,
          },
        },
      ],
    },
  ],
}
