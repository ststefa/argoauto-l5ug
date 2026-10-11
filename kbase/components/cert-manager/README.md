# cert-manager

This component installs cert-manager and its CRDs into the `cert-manager` namespace. It is deliberately only the controller layer: DNS credentials, ACME issuers, and application certificates live in separate components.

## Namecheap DNS01

Namecheap is not a built-in cert-manager DNS01 provider. The required external webhook is vendored in the sibling component `../crtmgr-ncheap-webhook`. That component must be installed after cert-manager, because it registers an extension APIService consumed by the issuer solver:

```yaml
webhook:
  groupName: acme.namecheap.com
  solverName: namecheap
```

`../crtmgr-ncheap-issuer` supplies the staging and production ClusterIssuers. A `ClusterIssuer` is cluster-scoped and therefore intentionally has no `metadata.namespace`; cert-manager reads its ACME account and Namecheap credential Secrets from the controller's cluster-resource namespace, which is `cert-manager` here. The required `namecheap-credentials` Secret must therefore live in this namespace and contain `apiKey` and `apiUser` keys. Certificate resources are owned by the applications that need them; they write TLS Secrets that Traefik can reference through `IngressRoute.spec.tls.secretName`.

All three components can be committed and deployed together. They are distinct ArgoCD Applications so the Namecheap provider remains optional, but their dependency chain is automatic: cert-manager supplies the CRDs, the webhook supplies the solver APIService, and the issuers use that solver. The KBase ApplicationSet retries an initial failed sync while an earlier dependency is still becoming ready.

For a new DNS setup, use the staging issuer first. Namecheap must also allowlist the public source IP from which the cluster calls its API.
