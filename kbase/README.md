# kbase

A collection of kubernetes tools that should be present in any cluster. Any directory in kbase is a distinct component that should preferrably use its own namespace. The entrypoint to any kbase component is `<component-dir>/kustomize.yaml`

The file `projects/kbase.yaml` is responsible for creating a new argo-application for any directory in kbase.

Cluster-specific settings:

- `kbase/csinfs/csinfs-storageclass.yaml`
    - parameters.subDir

        Should be set to a unique name identifying the cluster. This is used so that any k8s cluster is "chrooted" in its own slice of NFS storage.
