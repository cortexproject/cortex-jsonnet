local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  'cortex-object-store.json':
    ($.dashboard('Cortex / Object Store') + { uid: 'd5a3a4489d57c733b5677fb55370a723' })
    .addClusterSelectorTemplates()
    .addRow(
      $.row('Components')
      .addPanel(
        $.timeseriesPanel('RPS / component', unit='rps') +
        $.queryPanel('sum by(component) (rate(thanos_objstore_bucket_operations_total{%s}[$__rate_interval]))' % $.namespaceMatcher(), '{{component}}') +
        $.stack,
      )
      .addPanel(
        $.timeseriesPanel('Error rate / component', unit='percentunit') +
        $.queryPanel('sum by(component) (rate(thanos_objstore_bucket_operation_failures_total{%s}[$__rate_interval])) / sum by(component) (rate(thanos_objstore_bucket_operations_total{%s}[$__rate_interval]))' % [$.namespaceMatcher(), $.namespaceMatcher()], '{{component}}')
      )
    )
    .addRow(
      $.row('Operations')
      .addPanel(
        $.timeseriesPanel('RPS / operation', unit='rps') +
        $.queryPanel('sum by(operation) (rate(thanos_objstore_bucket_operations_total{%s}[$__rate_interval]))' % $.namespaceMatcher(), '{{operation}}') +
        $.stack,
      )
      .addPanel(
        $.timeseriesPanel('Error rate / operation', unit='percentunit') +
        $.queryPanel('sum by(operation) (rate(thanos_objstore_bucket_operation_failures_total{%s}[$__rate_interval])) / sum by(operation) (rate(thanos_objstore_bucket_operations_total{%s}[$__rate_interval]))' % [$.namespaceMatcher(), $.namespaceMatcher()], '{{operation}}')
      )
    )
    .addRow(
      $.row('')
      .addPanel(
        $.timeseriesPanel('Op: Get') +
        $.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', '{%s,operation="get"}' % $.namespaceMatcher()),
      )
      .addPanel(
        $.timeseriesPanel('Op: GetRange') +
        $.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', '{%s,operation="get_range"}' % $.namespaceMatcher()),
      )
      .addPanel(
        $.timeseriesPanel('Op: Exists') +
        $.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', '{%s,operation="exists"}' % $.namespaceMatcher()),
      )
    )
    .addRow(
      $.row('')
      .addPanel(
        $.timeseriesPanel('Op: Attributes') +
        $.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', '{%s,operation="attributes"}' % $.namespaceMatcher()),
      )
      .addPanel(
        $.timeseriesPanel('Op: Upload') +
        $.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', '{%s,operation="upload"}' % $.namespaceMatcher()),
      )
      .addPanel(
        $.timeseriesPanel('Op: Delete') +
        $.latencyPanel('thanos_objstore_bucket_operation_duration_seconds', '{%s,operation="delete"}' % $.namespaceMatcher()),
      )
    ),
}
