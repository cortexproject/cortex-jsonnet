local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  'alertmanager.json':
    ($.dashboard('Cortex / Alertmanager') + { uid: 'a76bee5913c97c918d9e56a3cc88cc28' })
    .addClusterSelectorTemplates()
    .addRow(
      ($.row('Headlines') + {
         height: '100px',
         showTitle: false,
       })
      .addPanel(
        $.timeseriesPanel('Total Alerts') +
        $.statPanel('sum(cluster_job_%s:cortex_alertmanager_alerts:sum{%s})' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.alertmanager)], format='short')
      )
      .addPanel(
        $.timeseriesPanel('Total Silences') +
        $.statPanel('sum(cluster_job_%s:cortex_alertmanager_silences:sum{%s})' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.alertmanager)], format='short')
      )
      .addPanel(
        $.timeseriesPanel('Tenants') +
        $.statPanel('max(cortex_alertmanager_tenants_discovered{%s})' % $.jobMatcher($._config.job_names.alertmanager), format='short')
      )
    )
    .addRow(
      $.row('Alerts Received')
      .addPanel(
        $.timeseriesPanel('APS') +
        $.queryPanel(
          [
            |||
              sum(cluster_job:cortex_alertmanager_alerts_received_total:rate5m{%s})
              -
              sum(cluster_job:cortex_alertmanager_alerts_invalid_total:rate5m{%s})
            ||| % [$.jobMatcher($._config.job_names.alertmanager), $.jobMatcher($._config.job_names.alertmanager)],
            'sum(cluster_job:cortex_alertmanager_alerts_invalid_total:rate5m{%s})' % $.jobMatcher($._config.job_names.alertmanager),
          ],
          ['success', 'failed']
        )
      )
    )
    .addRow(
      $.row('Alert Notifications')
      .addPanel(
        $.timeseriesPanel('NPS') +
        $.queryPanel(
          [
            |||
              sum(cluster_job_integration:cortex_alertmanager_notifications_total:rate5m{%s})
              -
              sum(cluster_job_integration:cortex_alertmanager_notifications_failed_total:rate5m{%s})
            ||| % [$.jobMatcher($._config.job_names.alertmanager), $.jobMatcher($._config.job_names.alertmanager)],
            'sum(cluster_job_integration:cortex_alertmanager_notifications_failed_total:rate5m{%s})' % $.jobMatcher($._config.job_names.alertmanager),
          ],
          ['success', 'failed']
        )
      )
      .addPanel(
        $.timeseriesPanel('NPS by integration') +
        $.queryPanel(
          [
            |||
              (
              sum(cluster_job_integration:cortex_alertmanager_notifications_total:rate5m{%s}) by(integration)
              -
              sum(cluster_job_integration:cortex_alertmanager_notifications_failed_total:rate5m{%s}) by(integration)
              ) > 0
              or on () vector(0)
            ||| % [$.jobMatcher($._config.job_names.alertmanager), $.jobMatcher($._config.job_names.alertmanager)],
            'sum(cluster_job_integration:cortex_alertmanager_notifications_failed_total:rate5m{%s}) by(integration)' % $.jobMatcher($._config.job_names.alertmanager),
          ],
          ['success - {{ integration }}', 'failed - {{ integration }}']
        )
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        $.latencyPanel('cortex_alertmanager_notification_latency_seconds', '{%s}' % $.jobMatcher($._config.job_names.alertmanager))
      )
    )
    .addRow(
      $.row('Configuration API (gateway) + Alertmanager UI')
      .addPanel(
        $.timeseriesPanel('QPS') +
        $.qpsPanel('cortex_request_duration_seconds_count{%s, route=~"api_v1_alerts|alertmanager"}' % $.jobMatcher($._config.job_names.gateway))
      )
      .addPanel(
        $.timeseriesPanel('Latency', unit='ms') +
        utils.latencyRecordingRulePanel('cortex_request_duration_seconds', $.jobSelector($._config.job_names.gateway) + [utils.selector.re('route', 'api_v1_alerts|alertmanager')])
      )
    )
    .addRows(
      $.getObjectStoreRows('Alertmanager Configuration Object Store (Alertmanager accesses)', 'alertmanager-storage')
    )
    .addRow(
      $.row('Replication')
      .addPanel(
        $.timeseriesPanel('Per %s Tenants' % $._config.per_instance_label) +
        $.queryPanel(
          'max by(%s) (cortex_alertmanager_tenants_owned{%s})' % [$._config.per_instance_label, $.jobMatcher($._config.job_names.alertmanager)],
          '{{%s}}' % $._config.per_instance_label
        ) +
        $.stack
      )
      .addPanel(
        $.timeseriesPanel('Per %s Alerts' % $._config.per_instance_label) +
        $.queryPanel(
          'sum by(%s) (cluster_job_%s:cortex_alertmanager_alerts:sum{%s})' % [$._config.per_instance_label, $._config.per_instance_label, $.jobMatcher($._config.job_names.alertmanager)],
          '{{%s}}' % $._config.per_instance_label
        ) +
        $.stack
      )
      .addPanel(
        $.timeseriesPanel('Per %s Silences' % $._config.per_instance_label) +
        $.queryPanel(
          'sum by(%s) (cluster_job_%s:cortex_alertmanager_silences:sum{%s})' % [$._config.per_instance_label, $._config.per_instance_label, $.jobMatcher($._config.job_names.alertmanager)],
          '{{%s}}' % $._config.per_instance_label
        ) +
        $.stack
      )
    )
    .addRow(
      $.row('Tenant Configuration Sync')
      .addPanel(
        $.timeseriesPanel('Syncs/sec') +
        $.queryPanel(
          [
            |||
              sum(rate(cortex_alertmanager_sync_configs_total{%s}[$__rate_interval]))
              -
              sum(rate(cortex_alertmanager_sync_configs_failed_total{%s}[$__rate_interval]))
            ||| % [$.jobMatcher($._config.job_names.alertmanager), $.jobMatcher($._config.job_names.alertmanager)],
            'sum(rate(cortex_alertmanager_sync_configs_failed_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.alertmanager),
          ],
          ['success', 'failed']
        )
      )
      .addPanel(
        $.timeseriesPanel('Syncs/sec (By Reason)') +
        $.queryPanel(
          'sum by(reason) (rate(cortex_alertmanager_sync_configs_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.alertmanager),
          '{{reason}}'
        )
      )
      .addPanel(
        $.timeseriesPanel('Ring Check Errors/sec') +
        $.queryPanel(
          'sum (rate(cortex_alertmanager_ring_check_errors_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.alertmanager),
          'errors'
        )
      )
    )
    .addRow(
      $.row('Sharding Initial State Sync')
      .addPanel(
        $.timeseriesPanel('Initial syncs /sec') +
        $.queryPanel(
          'sum by(outcome) (rate(cortex_alertmanager_state_initial_sync_completed_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.alertmanager),
          '{{outcome}}'
        ) + {
          targets: [
            target {
              interval: '1m',
            }
            for target in super.targets
          ],
        }
      )
      .addPanel(
        $.timeseriesPanel('Initial sync duration', unit='s') +
        $.latencyPanel('cortex_alertmanager_state_initial_sync_duration_seconds', '{%s}' % $.jobMatcher($._config.job_names.alertmanager)) + {
          targets: [
            target {
              interval: '1m',
            }
            for target in super.targets
          ],
        }
      )
      .addPanel(
        $.timeseriesPanel('Fetch state from other alertmanagers /sec') +
        $.queryPanel(
          [
            |||
              sum(rate(cortex_alertmanager_state_fetch_replica_state_total{%s}[$__rate_interval]))
              -
              sum(rate(cortex_alertmanager_state_fetch_replica_state_failed_total{%s}[$__rate_interval]))
            ||| % [$.jobMatcher($._config.job_names.alertmanager), $.jobMatcher($._config.job_names.alertmanager)],
            'sum(rate(cortex_alertmanager_state_fetch_replica_state_failed_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.alertmanager),
          ],
          ['success', 'failed']
        ) + {
          targets: [
            target {
              interval: '1m',
            }
            for target in super.targets
          ],
        }
      )
    )
    .addRow(
      $.row('Sharding Runtime State Sync')
      .addPanel(
        $.timeseriesPanel('Replicate state to other alertmanagers /sec') +
        $.queryPanel(
          [
            |||
              sum(cluster_job:cortex_alertmanager_state_replication_total:rate5m{%s})
              -
              sum(cluster_job:cortex_alertmanager_state_replication_failed_total:rate5m{%s})
            ||| % [$.jobMatcher($._config.job_names.alertmanager), $.jobMatcher($._config.job_names.alertmanager)],
            'sum(cluster_job:cortex_alertmanager_state_replication_failed_total:rate5m{%s})' % $.jobMatcher($._config.job_names.alertmanager),
          ],
          ['success', 'failed']
        )
      )
      .addPanel(
        $.timeseriesPanel('Merge state from other alertmanagers /sec') +
        $.queryPanel(
          [
            |||
              sum(cluster_job:cortex_alertmanager_partial_state_merges_total:rate5m{%s})
              -
              sum(cluster_job:cortex_alertmanager_partial_state_merges_failed_total:rate5m{%s})
            ||| % [$.jobMatcher($._config.job_names.alertmanager), $.jobMatcher($._config.job_names.alertmanager)],
            'sum(cluster_job:cortex_alertmanager_partial_state_merges_failed_total:rate5m{%s})' % $.jobMatcher($._config.job_names.alertmanager),
          ],
          ['success', 'failed']
        )
      )
      .addPanel(
        $.timeseriesPanel('Persist state to remote storage /sec') +
        $.queryPanel(
          [
            |||
              sum(rate(cortex_alertmanager_state_persist_total{%s}[$__rate_interval]))
              -
              sum(rate(cortex_alertmanager_state_persist_failed_total{%s}[$__rate_interval]))
            ||| % [$.jobMatcher($._config.job_names.alertmanager), $.jobMatcher($._config.job_names.alertmanager)],
            'sum(rate(cortex_alertmanager_state_persist_failed_total{%s}[$__rate_interval]))' % $.jobMatcher($._config.job_names.alertmanager),
          ],
          ['success', 'failed']
        )
      )
    ),
}
