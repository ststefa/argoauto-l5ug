# KBase

A collection of kubernetes tools that I consider useful for any cluster.

To make it composable, kbase is split into `components` (acting as a "base") and `clusters` (referenced from the argo app).

A cluster directory references zero or more components through kustomize. Any required per-cluster customization is done in the cluster directory.

Any component in kbase is a distinct component that should preferrably use its own namespace.

The file `/projects/kbase.yaml` uses a git generator to create a new argo-application for any directory in `kbase/clusters/<cluster-name>/<app-name>`.

## KBase Components

Collection of things that are useful for a cluster.

Inter-dependencies should be minimal but cannot be prevented entirely and have to be managed by convention:

- (Cluster-) Role bindings to k8s users should not be made part of the component. Like e.g. a mapping between a component-specific role and an OIDC user. Instead, they're assigned centrally in `kbase/components/rbac`. In case only a subset of components is assigned to a cluster, this can lead to bindings for which no role exists. This is not beautiful bot does not cause harm and is not considered invalid by k8s. The alternate approach (i.e., to make such assignments a part of each component) creates an widespread dependency between the components and central user/role names. I consider that the greater evil.

### cert-manager

TODO: Resolver for namecheap missing (only poorly maintained out-of-band webhook). Try to manage DNS for nom.cx with cloudflare?

### csinfs

A NFS driver (<https://github.com/kubernetes-csi/csi-driver-nfs>), hooked up to an internal NFS server

Cluster overlays must set a unique `subDir` template for each StorageClass. The NFS CSI driver expands PVC/PV metadata in this field, so l5ug uses a flat pattern with the cluster name, PVC namespace, PVC name, and PV name. Avoid nested `subDir` layouts here: the driver only removes the final directory on PV deletion, which would leave parent directories behind.

The StorageClasses also set `mountPermissions` so new PVC directories are writable by non-root workloads such as Traefik without manual `chown` on the NFS server.

### dashboard

A k8s management dashboard (<https://github.com/kubernetes/dashboard>).

WIP!

Has a problematic list of dependencies, see <https://github.com/kubernetes/dashboard/blob/master/charts/kubernetes-dashboard/Chart.yaml>

### rbac

A standard set of permissions that serves as my baseline and should be applied to any cluster. Maps OIDC roles

To allow for finegrained adjustments, API groups have their own files. oidc-crb.yaml assigns them to OIDC roles.

### sealedsecrets

The Bitnami SealedSecrets operator (<https://github.com/bitnami-labs/sealed-secrets>) adds the ability to create encrypted SealedSecrets. These will in turn create decrypted secrets with the same name in the same namespace. The mechanism relies on a cluster-wide shared secret that is created upon installation.

This might be not so nice for e.g. helmcharts, which typically include Secrets. These would have to be replaced by SealedSecrets one by one.

If managing multiple clusters with one argocd then all clusters need the same internal secret so that the SealedSecrets will be decryptable on each of them.

Rivals with ksops.

#### Creating SealedSecrets

1. Create a json/yaml-encoded Secret somehow (note use of `--dry-run` - this is just a local file!):

    ```sh
    echo -n bar | kubectl create -n foo secret generic mysecret --dry-run=client --from-file=foo=/dev/stdin -o json > mysecret.json
    ```

1. Encrypt it

    ```sh
    kubeseal -f mysecret.json -w mysealedsecret.json
    ```

    At this point mysealedsecret.json is encrypted

1. Apply the SealedSecret

    ```sh
    kubectl create -f mysealedsecret.json
    ```

    The operator will swiftly create an unsealed standard Secret

1. Verify

    ```sh
    kubectl get -n foo secret mysecret -o yaml
    ```

#### Removing SealedSecrets

Remove the SealedSecret. The operator will then remove the plain secret

```sh
$ kubectl delete -n foo sealedsecrets.bitnami.com mysecret
sealedsecret.bitnami.com "mysecret" deleted
$ kubectl get -n foo secret mysecret -o yaml
Error from server (NotFound): secrets "mysecret" not found
```

### traefik

The ingress handler. Especially in conjunction with k3s, make sure to disable the k3s default traefik and use this one. The disabling is managed by puppet.

Traefik stores ACME state in a small PVC. Do not let that PVC use k3s
`local-path` storage: a local-path PV is pinned to the node where it was
created, which means Traefik cannot move to another node when the original node
is NotReady. The component values request `nfs-fast` for this reason.

If an existing cluster already has a `traefik/traefik` PVC on `local-path`,
migrate it deliberately instead of relying on ArgoCD to patch the bound PVC in
place. Back up `/data/acme.json`, scale Traefik down, recreate the PVC on
`nfs-fast`, restore `acme.json`, then scale Traefik back up and verify that the
`traefik` Service has endpoints.
