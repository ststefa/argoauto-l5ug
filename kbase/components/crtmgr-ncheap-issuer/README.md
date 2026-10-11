# Namecheap ClusterIssuers

This component creates the staging and production Let's Encrypt ClusterIssuers for the Namecheap DNS01 webhook. It also decrypts `namecheap-credentials.sops.yaml` with KSOPS into the `namecheap-credentials` Secret in the `cert-manager` namespace.

The secret must contain `apiKey` and `apiUser`. It is separate from Traefik's older `namecheap-api` Secret because the cert-manager webhook expects different key names. It may contain the same Namecheap API key and user.

ClusterIssuers are cluster-scoped. cert-manager reads their ACME account and DNS credential Secrets from its cluster-resource namespace, which is `cert-manager` in this installation.

The l5ug overlay includes a staging Certificate for `certmgr-test.l5ug.nom.cx`. It is a DNS01 smoke test only and is not referenced by Traefik. A ready Certificate confirms that the Namecheap webhook and credentials work end to end before any production certificate or ingress is changed.
