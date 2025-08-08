# kbase

A collection of kubernetes tools that should be present in any cluster. Any directory in kbase is a distinct component that should preferrably use its own namespace.

The base of each components is located in `components/<component-name>`.

As components might to be assembled and kustomized by cluster, the argocd applicationset references `cluster/<clustername>/<component-name>. Only components which exist there will be applied to the realted cluster. Also, kustomization for each cluster happens there.

`The entrypoint to any kbase component is `<component-dir>/kustomize.yaml`

The file `/projects/kbase.yaml` is responsible for creating a new argo-application for any directory in kbase.

## Cluster-specific settings

TODO: Handle differences through an additional layer for clusters. This increases complexity but make kbase modular and parametrizable.

- `kbase/csinfs/csinfs-storageclass.yaml`
    - parameters.subDir

        Should be set to a unique name identifying the cluster. This is used so that any k8s cluster is "chrooted" in its own slice of NFS storage.
