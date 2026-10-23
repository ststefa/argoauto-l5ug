# NFS Test

`nfstest` is a small FileBrowser Quantum deployment for manually testing state on both NFS StorageClasses. The UI exposes the two separately labelled sources `NFS fast` and `NFS slow`, backed by PVCs created with `nfs-fast` and `nfs-slow`.

The FileBrowser configuration and user database are intentionally ephemeral. Only files below those two NFS paths survive a pod restart, so state behavior is easy to inspect. Authentication is disabled,.

After syncing `test-nfstest`, open `https://nfstest.l5ug.nom.cx`, create or upload files in both directories, and restart the Deployment to confirm that they remain:

```sh
kubectl -n nfstest get pvc,pv,pods
kubectl -n nfstest rollout restart deploy/nfstest
kubectl -n nfstest rollout status deploy/nfstest
```
