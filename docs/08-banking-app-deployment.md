# Banking App Deployment on AKS

This guide explains how the `banking-app` Kubernetes Deployment and Service work, how to apply and check them, and what we learned from the reported Gunicorn timeout. Commands are shown for Windows PowerShell from the project root unless a step says otherwise.

## 1. What the Deployment does

The manifest in `k8s/deployment.yaml` asks Kubernetes to run two copies (replicas) of the banking app:

- Deployment name: `banking-app`
- Namespace: `default`
- Container image: `akscicd1p54c.azurecr.io/aks-flask-app:v1`
- Container port: `5000`
- Health endpoint: `/health`

Kubernetes keeps the number of matching pods at two. If a pod exits, the Deployment works to create a replacement. The Deployment's pod label is `app: banking-app`; the Service uses that label to find the pods.

The Dockerfile starts Gunicorn listening on `0.0.0.0:5000`. The Flask app defines `/health`, which returns JSON with `status` set to `healthy`.

The Deployment has both readiness and liveness probes on `/health`:

- **Readiness** checks whether a pod is ready to receive traffic. A pod that is not ready is left out of the Service's ready endpoints.
- **Liveness** checks whether a container is still responding. Repeated liveness failures can cause Kubernetes to restart the container.

The current probes start after 5 seconds for readiness and 30 seconds for liveness, and then check every 5 and 10 seconds respectively. Each probe has a 3-second timeout and a failure threshold of 3. The Deployment also requests `100m` CPU and `128Mi` memory per pod and sets limits of `500m` CPU and `512Mi` memory.

## 2. What the Service does

`k8s/service.yaml` creates the `banking-service` Service in the `default` namespace. It is a `ClusterIP`, so it is reachable from inside the Kubernetes cluster, not directly from the public internet.

The Service selects pods labelled `app: banking-app` and maps:

```text
banking-service:80/TCP  ->  matching pod:5000/TCP
```

Kubernetes distributes Service traffic among matching ready pods. Since the Deployment requests two replicas, both healthy and ready banking pods can receive traffic. No external-facing Service or ingress is configured here.

## 3. Apply the manifests

The following local client-side dry-run commands were used to check that each manifest can be read by `kubectl`. They do not create resources in the cluster:

```powershell
kubectl create --dry-run=client --validate=false -f k8s\deployment.yaml -o name
kubectl create --dry-run=client --validate=false -f k8s\service.yaml -o name
```

They print the resource names, such as `deployment.apps/banking-app` and `service/banking-service`. `--dry-run=client` means the request is checked locally rather than submitted to the cluster; `--validate=false` skips server-side schema validation.

To create or update the resources in the currently selected Kubernetes cluster, run these from the project root:

```powershell
kubectl apply -f k8s\deployment.yaml
kubectl apply -f k8s\service.yaml
```

`kubectl apply` sends each manifest to the active cluster. The first command creates or updates the Deployment and begins creating pods. The second creates or updates the Service. These are deployment commands and were not run while writing this guide.

Confirm the Deployment's rollout:

```powershell
kubectl rollout status deployment/banking-app
```

This waits for Kubernetes to report the Deployment as successfully rolled out. A successful message usually says the deployment has successfully rolled out.

Check the pods and Service:

```powershell
kubectl get pods -l app=banking-app -o wide
kubectl get service banking-service
kubectl get endpoints banking-service
```

- `kubectl get pods` shows the two selected pods, their readiness, restart counts, and node placement.
- `kubectl get service` shows the Service type and its cluster-internal IP and port.
- `kubectl get endpoints` shows the ready pod IPs and target ports currently selected for Service traffic. If there are no endpoints, check that the pods are ready and their labels match the Service selector.

Expected state is two pods that are `Running` and ready (`1/1` for each), with zero or the expected restart count, and a `ClusterIP` Service on port `80` pointing to pod port `5000`. Pod IPs and the Service IP are assigned by the cluster, so their exact values vary.

## 4. Test `/health` with port-forward

Because `banking-service` is internal to the cluster, forward a local port on your computer to the Service:

```powershell
kubectl port-forward service/banking-service 8080:80
```

This keeps a connection open from `localhost:8080` to port `80` on the Service. Leave this PowerShell window running. In a second PowerShell window, request the app's health endpoint:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

The expected response is JSON similar to:

```text
status
------
healthy
```

The exact display formatting depends on PowerShell. A successful response means the request reached the Flask `/health` route through the Service and port-forward. Stop the port-forward with Ctrl+C in its window when finished.

## 5. Gunicorn timeout and probe troubleshooting

The observed sequence reported for this deployment was:

1. Gunicorn logged a `WORKER TIMEOUT`.
2. Readiness and liveness probes failed.
3. One container restart was observed.
4. Later health checks succeeded.

The exact root cause of the Gunicorn worker timeout is **not yet confirmed**. The timeout and probe failures were observed, but this sequence alone does not prove why the worker stopped responding or prove that one particular probe caused the restart. The probes check the same `/health` endpoint; temporary unresponsiveness can make them fail while Gunicorn is recovering or restarting.

Use the following commands to inspect current pod status and events. Run them from any directory with the correct Kubernetes context selected:

```powershell
kubectl get pods -l app=banking-app -o wide
kubectl describe pod <pod-name>
```

The first command shows readiness and restart counts. Replace `<pod-name>` with one of the pod names shown. `kubectl describe pod` displays events, including probe failures, scheduling information, and container restart details.

Read the current container logs:

```powershell
kubectl logs <pod-name> -c banking-app
```

This shows the container's current logs. To inspect logs from the previous container instance after a restart:

```powershell
kubectl logs <pod-name> -c banking-app --previous
```

Previous logs can help capture the Gunicorn timeout or other messages from before the restart. Kubernetes may no longer have previous logs if the pod has been replaced again.

Check the Deployment and Service after recovery:

```powershell
kubectl get pods -l app=banking-app
kubectl get endpoints banking-service
kubectl rollout status deployment/banking-app
```

Look for both pods to become ready, the Service to have ready endpoints, and the rollout to complete. Then repeat the port-forward `/health` test above. A successful health response confirms the app was responding at the time of that test; it does not identify the earlier timeout's cause.

## Troubleshooting lessons

### Readiness fails but the container remains running

Readiness failure means Kubernetes is not currently treating the pod as ready for Service traffic. Check `kubectl describe pod` for probe events, and inspect current logs with `kubectl logs`. Confirm the app is listening on port `5000` and that `/health` responds.

### Liveness failures are followed by a restart

Repeated liveness probe failures can cause Kubernetes to restart the container. Check the pod's restart count and events with `kubectl get pods` and `kubectl describe pod`. Use `kubectl logs --previous` to inspect the last container instance when available.

### `kubectl port-forward` starts, but `/health` fails

Confirm both pods are ready and that `kubectl get endpoints banking-service` lists pod addresses. The Service selector must match `app: banking-app`, and the Service target port `5000` must match the application's listening port. Check logs and pod events before changing probe settings.

### The timeout happens again

Capture the pod name, timestamp, current and previous container logs, restart count, and events. These details help distinguish an application or worker issue from resource pressure, node issues, or transient startup delays. Do not treat the root cause as known until the logs and events support a diagnosis.

## Cost reminder

The AKS worker nodes, disks, load balancer resources, and other infrastructure can incur Azure charges while deployed. The two Kubernetes replicas share the configured node capacity, but they do not make the underlying Azure infrastructure free. Review current costs and pricing for the learning environment.
