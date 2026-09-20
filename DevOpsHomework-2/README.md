# DevOps Assignment — Season 2 (Lectures 9–12)

**Author:** Joe Daniel
**Enrollment:** 24bcs10214
**Course:** SST DevOps & Cloud [SWE]

Kubernetes assignments for lectures 9 through 12. All labs run on Minikube (Kubernetes v1.34.0, Docker driver) on Arch Linux.

| Lecture | Topic | Submission path | File to submit |
|---|---|---|---|
| **9** | Kubernetes Fundamentals | `session9-k8s/` | `session9-k8s/Readme.md` |
| **10** | Pods, ReplicaSets & Deployments | `DevOpsHomework-2/lecture-10/` | `DevOpsHomework-2/lecture-10/README.md` |
| **11** | Kubernetes Networking & Services | `DevOpsHomework-2/lecture-11/` | `DevOpsHomework-2/lecture-11/README.md` |
| **12** | Ingress, ConfigMaps & Secrets | `DevOpsHomework-2/lecture-12/` | `DevOpsHomework-2/lecture-12/README.md` |

Course manifests remain in their original session folders:

- `session9-k8s/`
- `session10-k8s-core-objects/`
- `session-11-kubernetes-services/`
- `session-12-ingress-configmaps-secrets/`

Each lecture README embeds terminal screenshots from its own `screenshots/` folder.

## What each lecture covers

**Lecture 10** — cluster health, Pod lifecycle phases, ImagePullBackOff and CrashLoopBackOff diagnosis, probes, init containers and sidecars, ReplicaSet vs StatefulSet vs DaemonSet, rolling updates and rollbacks, plus all four deployment strategies demonstrated end to end (RollingUpdate, Recreate, Blue-Green, Canary).

**Lecture 11** — the four-port model, all five Service types (ClusterIP, NodePort, LoadBalancer, ExternalName, Headless), Services without selectors, CoreDNS and FQDN resolution, identity invariance between Deployments and StatefulSets, load balancer cost optimisation, and the Minikube Docker-driver networking difference between Linux and macOS/Windows.

**Lecture 12** — ConfigMaps and why env vars need a restart, Secrets and the limits of base64, the trailing-newline gotcha, enterprise secret management, combined ConfigMap + Secret injection, the Ingress resource vs controller distinction, path-based and host-based routing, hybrid rules, and TLS termination.
