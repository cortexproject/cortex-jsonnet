local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  'cortex-parquet-converter-resources.json':
    ($.dashboard('Cortex / Parquet Converter Resources') + { uid: 'c603a418fc4b1f77e6f13386b24f64f3' })
    .addClusterSelectorTemplates()
    .addRow(
      $.row('CPU and Memory')
      .addPanel(
        $.containerCPUUsagePanel('CPU', 'parquet-converter'),
      )
      .addPanel(
        $.containerMemoryWorkingSetPanel('Memory (workingset)', 'parquet-converter'),
      )
      .addPanel(
        $.goHeapInUsePanel('Memory (go heap inuse)', $._config.job_names.parquet_converter),
      )
    )
    .addRow(
      $.row('Network')
      .addPanel(
        $.containerNetworkReceiveBytesPanel($._config.instance_names.parquet_converter),
      )
      .addPanel(
        $.containerNetworkTransmitBytesPanel($._config.instance_names.parquet_converter),
      )
    )
    .addRow(
      $.row('Disk')
      .addPanel(
        $.containerDiskWritesPanel('Disk Writes', 'parquet-converter'),
      )
      .addPanel(
        $.containerDiskReadsPanel('Disk Reads', 'parquet-converter'),
      )
      .addPanel(
        $.containerDiskSpaceUtilization('Disk Space Utilization', 'parquet-converter'),
      )
    ) + {
      templating+: {
        list: [
          // Do not allow to include all clusters/namespaces otherwise this dashboard
          // risks to explode because it shows resources per pod.
          l + (if (l.name == 'cluster' || l.name == 'namespace') then { includeAll: false } else {})
          for l in super.list
        ],
      },
    },
}
