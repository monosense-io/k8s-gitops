# Observability Runbook

This runbook contains quick checks and common commands for the metrics and logs stacks.

## Metrics (VictoriaMetrics)

- Check vmcluster components (infra):
  - `kubectl -n observability get deploy,sts | rg "vm(select|insert|storage)|vmauth|vmalert|alertmanager"`
- vmselect query (port-forward):
  - `kubectl -n observability port-forward svc/victoria-metrics-global-vmselect 8481:8481`
  - `curl -sf "http://127.0.0.1:8481/select/0/prometheus/api/v1/labels" | jq .status`
- vmagent remote write (apps):
  - `kubectl -n observability logs deploy/victoria-metrics-vmagent | rg "remote write" -n`
- Business rules loaded by vmalert:
  - `kubectl -n observability logs deploy/victoria-metrics-global-vmalert | rg "loaded"`

## Logs (VictoriaLogs)

- Health of vmauth (infra):
  - `curl -sf http://${OBSERVABILITY_LOG_ENDPOINT_HOST}:${OBSERVABILITY_LOG_ENDPOINT_PORT}/health | grep OK`
- Send a test log (from a debug pod):
  - `curl -s -X POST -H "Content-Type: application/json" -H "X-Scope-OrgID: ${OBSERVABILITY_LOG_TENANT}" \
    --data '{"message":"hello from $(hostname)","severity":"info"}' \
    http://${OBSERVABILITY_LOG_ENDPOINT_HOST}:${OBSERVABILITY_LOG_ENDPOINT_PORT}${OBSERVABILITY_LOG_ENDPOINT_PATH}`
- Query recently ingested logs via vmselect (adapt to your query tool):
  - `kubectl -n observability port-forward svc/victorialogs-vmselect 9428:9428`
  - Use Grafana Explore or vlselect API depending on your setup.

## Grafana

- Admin secret reference: `${OBSERVABILITY_GRAFANA_SECRET_PATH}` → Secret `grafana-admin-new` with `admin-user` and `admin-password`.
- Port-forward and login:
  - `kubectl -n observability port-forward svc/victoria-metrics-grafana 3000:80`
  - Open http://127.0.0.1:3000 with the admin credentials.

## Alerting

- Alertmanager status:
  - `kubectl -n observability get svc,deployment | rg alertmanager`
- Test alert path:
  - Temporarily create a PrometheusRule with a short `for: 0m` condition under `kubernetes/components/monitoring/business-metrics/` and confirm notifications reach the configured receiver.

