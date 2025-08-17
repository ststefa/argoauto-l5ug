# ArgoCD-Autopilot gitops for heldenzeit

This repo controls the argocd app on the l5ug cluster. ArgoCD in turn controls itself and all connected k8s clusters. See `bootstrap/argo-cd` which is brought in by the application in `bootstrap/argo-cd.yaml`.

To enable standardization across clusters, the "KBase" concept is used, see README there.

## Using ksops and vault

Secrets have to be encrypted. This is a challenge in a gitops approach because everything should be stored in git. Argo needs to be able to decrypt the secrets in order to operate.

Encryption if often handled with sops. It has a pluggable backend architecture. Most often, age keys are used as a backend. Each developer has its own key, which must be added to the list of keys allowed to decrypt a secret.

Another such age secret could be created for argocd so that it is able to decrypt. This approach has some downsides:

- Developers must be maintained manually, adding and removing them to the sops config of any relevant git repo.
- There is no gitopsy way of adding the age key (which is secret) to k8s. This is especially problematic if using multiple clusters, which is often the case (e.g. dev, int, prod)

Vault transit secrets are another possible backend which does not have these downsides. However, it has others

- A vault instance must be maintained
- Secrets cannot be decrypted if the vault instance is unreachable. This is both good and bad:
    - good: Leaving developers cannot decrypt secrets anymore
    - bad: Vault becomes a crucial component. If it's not available, nobody can decrypt. No developer, no argocd

The ksops tool allows to combine sops and kustomize. It requires a rather hacky setup, especially if combined with vault transit secrets. This can be found in `bootstrap/argo-cd/patches/argocd-dep-ksops.yaml` and `bootstrap/argo-cd/patches/argocd-dep-vault.yaml`. The idea is to

- Patch the ksops binary into the argocd-repo-server
- Create a vault token using the kubernetes-auth method and refresh it regularly

Secrets can then be encrypted by a developer using a vault transit secret. Argo will be able to decrypt them upon deployment using a generator which uses the ksops binary using the same transit secret.

## Managing Other Clusters

See "Managing Other Clusters" in [Obsidian:ArgoCD notes](obsidian://adv-uri?vault=notes&uid=4f30bf66-bcbc-440e-89e3-0c96999beb21&filepath=ArgoCD%20notes.md)

(If the link does not work, go there manually)
