# ArgoCD-Autopilot gitops for heldenzeit

This config controls the argocd app on the l5ug cluster. ArgoCD in turn controls itself and all connected k8s clusters.

To enable standardization across clusters, the "KBase" concept is used, see README there.

## Using ksops and vault

Secrets have to be encrypted. This is a challenge in a gitops approach because argo needs to be able to decrypt them.

The ksops tool allows to do this. It requires a rather hacky setup, especially if combined with vault transit secrets. This can be found in `bootstrap/argo-cd/patches/argocd-dep-ksops.yaml` and `bootstrap/argo-cd/patches/argocd-dep-vault.yaml`. The idea is to

- Patch the ksops binary into the argocd-repo-server
- Create a vault token using the kubernetes-auth method and refresh it regularly

Secret can now be encrypted by a developer using a vault transit secret. Argo will be able to decrypt them upon deployment using a generator which uses the ksops binary using the same transit secret.

## Managing Other Clusters

See "Managing Other Clusters" in [Obsidian:ArgoCD notes](obsidian://adv-uri?vault=notes&uid=4f30bf66-bcbc-440e-89e3-0c96999beb21&filepath=ArgoCD%20notes.md)

(If the link does not work, go there manually)
