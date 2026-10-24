# NFS Test

`nfstest` is a small FileBrowser Quantum DaemonSet for manually testing state on both NFS StorageClasses. It runs one Pod per node, including a tainted control-plane node, and exposes the two separately labelled sources `NFS fast` and `NFS slow`.

The sources are backed by `ReadWriteMany` PVCs created with `nfs-fast` and `nfs-slow`. Each Pod writes a separate `nfs-smoke-test-<pod-name>.txt` file to both volumes at startup, including its node and Pod identity. The FileBrowser configuration and user database are intentionally ephemeral. Only files below those two NFS paths survive a pod restart, so state behavior is easy to inspect. Authentication is deliberately disabled, so the app must remain an internal experiment and must not be treated as a public file service.

After syncing `test-nfstest`, open `https://nfstest.l5ug.nom.cx`, create or upload files in both directories, and restart the DaemonSet to confirm that they remain:

```sh
kubectl -n nfstest get pvc,pv,pods
kubectl -n nfstest rollout restart daemonset/nfstest
kubectl -n nfstest rollout status daemonset/nfstest
```

The setup is meant to experiment with shared persistent state combined with pod evictions or other runtime changes.
