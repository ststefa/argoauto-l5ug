# Attempt to setup k8s dashboard.

<https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/>

A ServiceAccount is added through apps/dashapp/base/user.yaml. This is used for login. Get token using...

```sh
kubectl -n kubernetes-dashboard create token admin-user
```

Copypaste token on login page.
