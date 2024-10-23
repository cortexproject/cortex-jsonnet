local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {

  'cortex-config.json':
    ($.dashboard('Cortex / Config') + { uid: '61bb048ced9817b2d3e07677fb1c6290' })
    .addClusterSelectorTemplates()
    .addRow(
      $.row('Startup config file')
      .addPanel(
        $.timeseriesPanel('Startup config file hashes', unit='instances') +
        $.queryPanel('count(cortex_config_hash{%s}) by (sha256)' % $.namespaceMatcher(), 'sha256:{{sha256}}') +
        $.stack,
      )
    )
    .addRow(
      $.row('Runtime config file')
      .addPanel(
        $.timeseriesPanel('Runtime config file hashes', unit='instances') +
        $.queryPanel('count(cortex_runtime_config_hash{%s}) by (sha256)' % $.namespaceMatcher(), 'sha256:{{sha256}}') +
        $.stack,
      )
    ),
}
