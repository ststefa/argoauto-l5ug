# ArgoCD-Autopilot gitops for heldenzeit l5ug cluster

This config controls the argocd app on the l5ug cluster. ArgoCD in turn controls itself and the k8s installation.

Search "autopilot" in PIM for further info.

## Managing Other Clusters

To manage other cluster, they must be attached to argocd. This is done through a cluster secret (see https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)

The secret looks like so

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mycluster-secret
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: mycluster.example.com
  server: https://mycluster.example.com
  config: |
    {
      "bearerToken": "<authentication token>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64 encoded certificate>"
      }
    }
```

`bearerToken` and `caData` must be obtained from the cluster that should be managed.

### 1. Get `bearerToken`

This is a ServiceAccount token used by Argo CD to authenticate with the target Kubernetes cluster's API server.

  1. Create a ServiceAccount in the target cluster:

      ```bash
      $ kubectl create ns argocd
      $ kubectl create serviceaccount argocd-manager -n argocd
      $ kubectl create clusterrolebinding argocd-manager-rolebinding --clusterrole=cluster-admin --serviceaccount=argocd:argocd-manager
      ```

  1. Bind it to a cluster role with necessary permissions (example: cluster-admin):

      ```bash
      $ kubectl create clusterrolebinding argocd-manager-rolebinding --clusterrole=cluster-admin --serviceaccount=argocd:argocd-manager
      ```

  1. SA tokens are short-lived by default since k8s v1.24. As we need permanent access, this leaves two options:

      1. Recreate the token continuously, e.g. using a cronjob that essentially does the following in a loop:

          ```bash
          #!/bin/bash
          TOKEN=$(kubectl create token argocd-manager -n argocd)
          kubectl patch secret cluster-l5ug -n argocd -p "{\"stringData\":{\"config\":\"{\\\"bearerToken\\\":\\\"$TOKEN\\\"}\"}}"
          ```

          Quite ugly for my taste.

      1. Manually create a static secret

          ```sh
          cat <<EOF | kubectl apply -f -
          apiVersion: v1
          kind: Secret
          metadata:
              name: argocd-manager-token-static
              namespace: argocd
              annotations:
                  kubernetes.io/service-account.name: argocd-manager
          type: kubernetes.io/service-account-token
          EOF
          ```

          Then retrieve the token

          ```sh
          kubectl -n argocd get secret argocd-manager-token-static -o jsonpath='{.data.token}' | base64 --decode
          ```

### 2. `caData`

This is the public CA certificate (base64-encoded) of the target cluster’s Kubernetes API server, used to validate TLS connections. It is not secret!

Get it with

  ```bash
  kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"<CLUSTER_NAME>\")].cluster.certificate-authority-data}"
```

Once the information is collected, put it into the argo secret and store it in `bootstrap/argo-cd/argocd-clusters.sops.yaml`.
