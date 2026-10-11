# cert-manager Namecheap Webhook

This component vendors the Helm chart from <https://github.com/kelvie/cert-manager-webhook-namecheap> and wraps it for the kbase ApplicationSet layout. The checked-in chart resides in `vendor-chart/`, rather than the conventional `charts/` directory, because the repository-wide `.gitignore` treats `charts` as generated Helm/Kustomize output. `kustomization.yaml` uses `helmGlobals.chartHome: vendor-chart` to render it locally.

The chart installs the DNS01 webhook APIService used by cert-manager issuers with:

```yaml
groupName: acme.namecheap.com
solverName: namecheap
```

The vendored chart has local template fixes: `resources` rendering in `templates/deployment.yaml` uses `nindent` so Helm emits valid YAML when resource requests are configured, and the `ServiceAccount`, `Service`, and `Deployment` explicitly use the Helm release namespace. The latter avoids relying on ArgoCD's destination namespace when rendering the chart through Kustomize.

This component only installs the webhook. Namecheap credentials, ClusterIssuers, and Certificates are managed separately so they can be introduced and tested deliberately.
