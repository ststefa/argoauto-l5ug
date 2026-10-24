# ArgoCD-Autopilot gitops for heldenzeit

<!-- TOC -->

- [Overview](#overview)
- [Using ksops and vault](#using-ksops-and-vault)
- [Local Git Hooks](#local-git-hooks)
- [Managing Other Clusters](#managing-other-clusters)
- [Kubernetes Authentication and Authorization With OpenBao OIDC](#kubernetes-authentication-and-authorization-with-openbao-oidc)
    - [OpenBao Identity and Claims](#openbao-identity-and-claims)
    - [OIDC Provider and Client](#oidc-provider-and-client)
    - [Kubernetes API Server and Client](#kubernetes-api-server-and-client)
- [ArgoCD CLI Login With OpenBao OIDC](#argocd-cli-login-with-openbao-oidc)

<!-- /TOC -->

## Overview

This repo controls the argocd app on the k8s cluster. ArgoCD in turn controls itself and all connected clusters. See `bootstrap/argo-cd` which is brought in by the application in `bootstrap/argo-cd.yaml`.

By doing so, the setup is 100% declarative. I.e. there is nothing in the cluster that would be handled manually. That also makes the setup fully reproducible.

To enable standardization across clusters, the "KBase" concept is used, see README there.

The setup is mainly built around kustomize but also has some helm where this is the preferred distribution method of some tool. Kustomize and Helm can well work together. I consider it more composable to use Helm values as little as possible and do the configuration with kustomize. Your mileage may vary.

The repo also showcases the two kinds of argo application: *Directory based* and *kustomize based*. Things below `/apps` are organized in the former way while `/kbase` is structured in the latter. I find the "kustomize way" more expressive. Judge for yourself.

## Using ksops and vault

Also see <obsidian://adv-uri?vault=notes&uid=688d6704-e35e-4acb-b24b-b807495afee9&filepath=Enable%20ksops%20over%20vault.md>

Secrets have to be encrypted. This is a challenge in a gitops approach because everything should be stored in git. Argo needs to be able to decrypt the secrets in order to operate.

Encryption if often handled with sops. It has a pluggable backend architecture. Most often, age keys are used as a backend. Each developer has its own key, which must be added to the list of keys allowed to decrypt a secret.

Another such age secret could be created for argocd so that it is able to decrypt. This approach has some downsides:

- Developers must be maintained manually, adding and removing them to the sops config of any relevant git repo.
- There is no gitopsy way of adding the age key (which is secret) to k8s. This is especially problematic if using multiple clusters, which is often the case (e.g. dev, int, prod)

Vault transit secrets are another possible backend which does not have these downsides. However, it has others

- A vault instance must be maintained
- Secrets cannot be decrypted if the vault instance is unreachable. This is both good and bad:
    - good: Leaving developers cannot decrypt secrets anymore
    - bad: Vault becomes a critical component. If it's not available, nobody can decrypt. No developer, no argocd

The ksops tool allows to combine sops and kustomize. It requires a rather hacky setup, especially if combined with vault transit secrets. This can be found in `bootstrap/argo-cd/patches/argocd-dep-ksops.yaml` and `bootstrap/argo-cd/patches/argocd-dep-vault.yaml`. The idea is to

- Patch the ksops binary into the argocd-repo-server
- Create a vault token using the kubernetes-auth method and refresh it regularly
- Decrypt sops-encrypted secrets on the fly using that token

Secrets can then be encrypted by a developer using a vault transit secret. Argo will be able to decrypt them upon deployment using a so called **kustomize generator** which uses the ksops binary using the same transit secret.

## Local Git Hooks

The repo is prepared to use [prek](https://github.com/j178/prek) to enable a git precommit hook. Install the repository's Prek-managed Git hooks once after cloning:

```sh
just hooks-install
```

The pre-commit hook runs `just sops-check` and rejects files matched by `.sops.yaml` rules when they do not contain encrypted values.

Obviously, `just` and `prek` must be installed locally for this to work.

## Managing Other Clusters

See "Managing Other Clusters" in [Obsidian:ArgoCD notes](obsidian://adv-uri?vault=notes&uid=4f30bf66-bcbc-440e-89e3-0c96999beb21&filepath=ArgoCD%20notes.md)

## Kubernetes Authentication and Authorization With OpenBao OIDC

OpenBao is the OIDC identity provider for both Kubernetes and ArgoCD. The path is split into two responsibilities:

1. OpenBao authenticates a person and issues an ID token. Its `groups` claim carries the person's OpenBao Identity group names.
2. The Kubernetes API server verifies that token and passes the groups to Kubernetes RBAC. ArgoCD verifies the same token and maps the same groups to ArgoCD roles.

An OpenBao client assignment only decides who may obtain a token for that client. It does not grant Kubernetes or ArgoCD permissions. The permissions come solely from the `k8s_admin`, `k8s_editor`, and `k8s_viewer` groups emitted in the token.

### OpenBao Identity and Claims

Create or use the OpenBao Identity entities for the people that should be able to log in, then make each entity a member of one or more of these internal OpenBao groups:

| OpenBao group | Kubernetes role | ArgoCD role |
| --- | --- | --- |
| `k8s_admin` | `cluster-admin` plus the local baseline roles | `admin` |
| `k8s_editor` | built-in `edit` plus the local baseline roles | `argo_editor` |
| `k8s_viewer` | built-in `view` plus read-only local baseline roles | `readonly` |

The Kubernetes bindings live centrally in `kbase/components/rbac/oidc-crb.yaml`; the ArgoCD mappings are in `bootstrap/argo-cd/patches/argocd-rbac-cm.yaml`. Apply the KBase `rbac` component to every cluster that uses this login flow.

The provider must expose those memberships as an array-valued `groups` claim. In my setup, the existing `groups` scope has this shape:

```sh
bao write identity/oidc/scope/groups \
  description='Kubernetes and ArgoCD group memberships' \
  template='{"groups": {{identity.entity.groups.names}}}'
```

That is, the group memberships come from the entity definition in OpenBao.

The `k8s` assignment restricts the clients to the intended OpenBao entities or groups. Add a person to that assignment as well as to one of the authorization groups above; without the assignment, OpenBao refuses the authorization request.

### OIDC Provider and Client

The shared provider issuer is `https://bao.heldenzeit.net/v1/identity/oidc/provider/k8s`. It must advertise the `groups` and `k8s` scopes and list every client that is allowed to use it. The current setup shares the existing confidential `k8s` client between kubectl/K9s and the ArgoCD web UI, while the ArgoCD CLI gets its own public client in the next section.

The `k8s` client needs the browser callback used by kubelogin, the ArgoCD web callback, the `k8s` assignment, and authorization-code flow enabled. `authorization_code` is (in the current v2.7.1) not surfaced by the OpenBao web UI, so set it with the CLI:

```sh
bao write identity/oidc/client/k8s \
  client_type=confidential \
  authorization_code=true \
  assignments=k8s \
  redirect_uris='http://localhost:8000,https://argo.l5ug.nom.cx/auth/callback'
```

Read back the generated client ID and secret, keep the secret out of Git, and store the web client secret in the SOPS-managed `argocd-sso` Secret. The client ID is the audience expected by Kubernetes and is configured as ArgoCD's `clientID` in `bootstrap/argo-cd/patches/argocd-cm-auth.yaml`.

```sh
bao read identity/oidc/client/k8s
bao read identity/oidc/provider/k8s
```

If a second client is added, include its generated client ID in the provider's `allowed_client_ids`. Redirect URIs must match the requesting application exactly, including host, port, scheme, and path.

### Kubernetes API Server and Client

K3s passes API-server options through `kube-apiserver-arg`. Its host-managed K3s configuration must point to the OpenBao issuer and consume the `groups` claim. The bindings in this repository use the group names without a prefix, so disable the Kubernetes default `oidc:` group prefix explicitly:

```yaml
kube-apiserver-arg:
  - oidc-issuer-url=https://bao.heldenzeit.net/v1/identity/oidc/provider/k8s
  - oidc-client-id=<k8s-client-id>
  - oidc-groups-claim=groups
  - oidc-groups-prefix=-
```

The kubeconfig uses the `kubectl oidc-login get-token` exec plugin. It must request the same issuer and `k8s` client ID, plus the `k8s` and `groups` scopes. Because the shared client is confidential, keep its secret in local secure configuration if the plugin is configured to send it; never add that secret to this repository.

After changing API-server arguments, restart the relevant K3s server and obtain a fresh token. Verify authentication and authorization separately:

```sh
kubectl get nodes
kubectl auth can-i get nodes
kubectl auth can-i create deployments --all-namespaces
```

The first command proves that Kubernetes accepts the ID token. The two `can-i` checks reveal the effective permissions of the token's groups. A missing `groups` claim, a mismatched audience, or a prefixed group name commonly looks like a Kubernetes RBAC failure.

OpenBao scopes and assignments are described in the [OpenBao OIDC provider documentation](https://openbao.org/docs/concepts/oidc-provider/). Kubernetes documents the corresponding API-server OIDC flags in its [authentication reference](https://kubernetes.io/docs/reference/access-authn-authz/authentication/).

## ArgoCD CLI Login With OpenBao OIDC

ArgoCD uses OpenBao as its OIDC provider. The web UI and the ArgoCD CLI use different OIDC clients:

- The web UI uses the confidential client configured as `clientID` and `clientSecret` in `bootstrap/argo-cd/patches/argocd-cm-auth.yaml`.
- The CLI uses a separate public client configured as `cliClientID` in the same file.

This split is required because the CLI performs a local PKCE authorization-code flow and cannot authenticate with the confidential web client secret.

Create the CLI client in OpenBao with the CLI, not only through the web UI. The `authorization_code` setting is easy to miss in the UI, but the ArgoCD CLI SSO flow requires it:

```sh
bao write identity/oidc/client/argocd-cli \
  client_type=public \
  authorization_code=true \
  assignments=k8s \
  redirect_uris='http://localhost:8085/auth/callback'
```

Then get the generated client ID:

```sh
bao read -field=client_id identity/oidc/client/argocd-cli
```

Add that value to `bootstrap/argo-cd/patches/argocd-cm-auth.yaml` as `cliClientID`.

The ArgoCD config should look like this:

```yaml
oidc.config: |
  name: OpenBao
  issuer: https://bao.heldenzeit.net/v1/identity/oidc/provider/k8s
  clientID: tH3jslDrwkndgiqzeGzovWkgcbfdeyPu
  clientSecret: $argocd-sso:oidc.clientSecret
  cliClientID: 7vFA7yqp7PEY5x2yXgcQO2eqLAI8sDZE
  requestedIDTokenClaims:
     groups:
        essential: true
  requestedScopes:
     - openid
     - k8s
     - groups
```

The OpenBao provider must allow both client IDs because this setup uses one provider for both the existing k8s client and the new argocd-cli client:

```sh
bao read identity/oidc/provider/k8s
```

Expected:

```text
allowed_client_ids    [7vFA7yqp7PEY5x2yXgcQO2eqLAI8sDZE tH3jslDrwkndgiqzeGzovWkgcbfdeyPu]
```

Alternatively use a separate provider if preferred.

After changing ArgoCD OIDC config, restart the server so the new config is loaded:

```sh
kubectl -n argocd rollout restart deploy argocd-server
kubectl -n argocd rollout status deploy argocd-server
```

Log in. The ArgoCD CLI uses `http://localhost:8085/auth/callback` by default, which is why that URI must be registered on the Bao CLI client:

```sh
argocd login argo.l5ug.nom.cx --grpc-web --sso
argocd app list
```

If a different local callback port is needed, add the matching redirect URI to the Bao CLI client and pass it explicitly with `--sso-port`.

Common OIDC failures:

- `Redirect URI mismatch`: add the exact callback URI shown in the failed request to the Bao client, for example `http://localhost:8085/auth/callback`.
- `client not allowed to perform authorization code credential flow`: set `authorization_code=true` on the Bao client used by ArgoCD.
- `invalid_client: client failed to authenticate`: the CLI is trying to use a confidential client. Configure a public Bao client and set it as `cliClientID`.
- `unauthorized_client: client is not authorized to use the provider`: add the CLI client ID to `identity/oidc/provider/k8s` `allowed_client_ids`.
