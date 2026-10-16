# Namecheap ClusterIssuers

This component creates the staging and production Let's Encrypt ClusterIssuers for the Namecheap DNS01 webhook. It also decrypts `namecheap-credentials.sops.yaml` with KSOPS into the `namecheap-credentials` Secret in the `cert-manager` namespace.

The secret must contain `apiKey` and `apiUser`.

ClusterIssuers are cluster-scoped. cert-manager reads their ACME account and DNS credential Secrets from its cluster-resource namespace, which is `cert-manager` in this installation.

`nom.cx` uses split-horizon DNS: the cluster's internal nameservers intentionally do not serve the public Namecheap DNS01 records. Both issuers therefore use cert-manager's `waitInsteadOfSelfCheck: 60s`, which matches Traefik's existing `delayBeforeCheck: 60` plus `disablePropagationCheck` behavior. cert-manager waits after the webhook presents the TXT record and then lets the ACME server validate the public DNS view instead of failing against the internal one.

The l5ug overlay includes a staging Certificate for `certmgr-test.l5ug.nom.cx`. It is a DNS01 smoke test only and is not referenced by Traefik. A ready Certificate confirms that the Namecheap webhook and credentials work end to end before any production certificate or ingress is changed.
