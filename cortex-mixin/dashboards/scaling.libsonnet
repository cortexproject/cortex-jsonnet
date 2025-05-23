local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {

  'cortex-scaling.json':
    ($.dashboard('Cortex / Scaling') + { uid: '88c041017b96856c9176e07cf557bdcf' })
    .addClusterSelectorTemplates()
    .addRow(
      ($.row('Cortex Service Scaling') + { height: '200px' })
      .addPanel({
        type: 'text',
        title: '',
        options: {
          content: |||
            This dashboards shows any services which are not scaled correctly.
            The table below gives the required number of replicas and the reason why.
            We only show services without enough replicas.

            Reasons:
            - **sample_rate**: There are not enough replicas to handle the
              sample rate.  Applies to distributor and ingesters.
            - **active_series**: There are not enough replicas
              to handle the number of active series.  Applies to ingesters.
            - **cpu_usage**: There are not enough replicas
              based on the CPU usage of the jobs vs the resource requests.
              Applies to all jobs.
            - **memory_usage**: There are not enough replicas based on the memory
              usage vs the resource requests.  Applies to all jobs.
            - **active_series_limits**: There are not enough replicas to hold 60% of the
              sum of all the per tenant series limits.
            - **sample_rate_limits**: There are not enough replicas to handle 60% of the
              sum of all the per tenant rate limits.
          |||,
          mode: 'markdown',
        },
      })
    )
    .addRow(
      ($.row('Scaling') + { height: '400px' })
      .addPanel(
        $.timeseriesPanel('Workload-based scaling') + { sort: { col: 0, desc: false } } +
        $.tablePanel([
          |||
            sort_desc(
              cluster_namespace_deployment_reason:required_replicas:count{cluster=~"$cluster", namespace=~"$namespace"}
                > ignoring(reason) group_left
              cluster_namespace_deployment:actual_replicas:count{cluster=~"$cluster", namespace=~"$namespace"}
            )
          |||,
        ], [
          $.overrideHidden('__name__'),
          $.overrideHidden('Time'),
          $.overrideDisplayName('cluster', 'Cluster'),
          $.overrideDisplayName('namespace', 'Namespace'),
          $.overrideDisplayName('deployment', 'Service'),
          $.overrideDisplayName('reason', 'Reason'),
          $.overrideDisplayName('Value', 'Required Replicas'),
        ])
      )
    ),
}
