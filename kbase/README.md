# KBase

A collection of kubernetes tools that I consider useful for any cluster.

To make it composable, kbase is split into `components` (acting as a "base") and `clusters` (referenced from the argo app).

A cluster directory references zero or more components through kustomize. Any required per-cluster customization is done in the cluster directory.

Any component in kbase is a distinct component that should preferrably use its own namespace.

The file `/projects/kbase.yaml` is responsible for creating a new argo-application for any directory in `kbase/clusters/<cluster-name>/<app-name>`.

## KBase Components

### csinfs

A NFS driver, hooked up to an internal NFS server

### dashboard

A k8s management dashboard. WIP

### rbac

A standard set of permissions that serves as my baseline and should be applied to any cluster.

### sealedsecrets

The Bitnami SealedSecrets operator

### traefik

The ingress handler. Especially in conjunction with k3s, make sure to disable the k3s default traefik and use this one. The disabling is managed by puppet.
