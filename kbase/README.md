# KBase

A collection of kubernetes tools that I consider useful for any cluster.

To make it composable, kbase is split into `components` (acting as a "base") and `clusters` (referenced from the argo app).

A cluster directory references zero or more components through kustomize. Any required per-cluster customization is done in the cluster directory.

Any component in kbase is a distinct component that should preferrably use its own namespace.

The file `/projects/kbase.yaml` uses a git generator to create a new argo-application for any directory in `kbase/clusters/<cluster-name>/<app-name>`.

### Application Reconciliation

Each cluster component becomes its own ArgoCD Application. Components may be committed and deployed together even when one provides CRDs, an APIService, or another prerequisite for the next one. The ApplicationSet enables automated sync, pruning, and self-healing for every generated application. It also retries a failed initial sync up to ten times, starting with a five-second delay and using exponential backoff up to three minutes. This handles normal startup races, such as a dependent component being applied before its CRD or APIService has become ready, without requiring a manual sync or another commit. A persistent configuration error remains visible after the retry limit is reached.

## KBase Components

Collection of things that are useful for a cluster.

Inter-dependencies should be minimal but cannot be prevented entirely and have to be managed by convention:

- (Cluster-) Role bindings to k8s users should not be made part of the component. Like e.g. a mapping between a component-specific role and an OIDC user. Instead, they're assigned centrally in `kbase/components/rbac`. In case only a subset of components is assigned to a cluster, this can lead to bindings for which no role exists. This is not beautiful bot does not cause harm and is not considered invalid by k8s. The alternate approach (i.e., to make such assignments a part of each component) creates an widespread dependency between the components and central user/role names. I consider that the greater evil.

### cert-manager

cert-manager is installed as a kbase component, but issuing public ACME certificates for `nom.cx` still needs a DNS01 solver decision. cert-manager supports several DNS providers in-tree, but Namecheap is not one of them; using Namecheap requires an external DNS01 webhook. The cleaner long-term option is to move or delegate ACME challenge DNS to a provider with first-class cert-manager support, such as Cloudflare or Route53.

The Namecheap webhook is vendored as its own kbase component, `crtmgr-ncheap-webhook`. It installs an extension APIService with the solver group `acme.namecheap.com`. The webhook is intentionally separate from the cert-manager component so cert-manager can be installed and become healthy before the extension APIService is added.

`crtmgr-ncheap-issuer` adds staging and production ClusterIssuers:

- `letsencrypt-namecheap-staging`
- `letsencrypt-namecheap-production`

All three components can be committed and deployed together. They are separate ArgoCD Applications so the Namecheap provider remains optional, but the KBase ApplicationSet retries an initial failed sync while cert-manager CRDs or the webhook APIService are still becoming ready.

The webhook and issuers alone do not issue certificates. The next required pieces are:

- a SOPS-managed `namecheap-credentials` Secret in the `cert-manager` namespace with `apiKey` and `apiUser`
- `Certificate` resources whose `secretName` can be referenced from Traefik `IngressRoute` resources

Namecheap API access also requires that Namecheap has the cluster's public source IP allowlisted for API calls.

The expected credentials Secret shape is:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: namecheap-credentials
  namespace: cert-manager
type: Opaque
stringData:
  apiKey: ...
  apiUser: ...
```

Each public `IngressRoute` uses a cert-manager `Certificate` in the same namespace. cert-manager writes its TLS Secret there and Traefik references it through `tls.secretName`; this frees Traefik from acting as ACME resolver amd eliminates ACME state PVC, or Namecheap credentials.

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

Public TLS certificates are managed by cert-manager. Traefik consumes their Kubernetes Secrets directly and has no persistent ACME state or dependency on ReadWriteMany storage like NFS.
