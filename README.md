# GitOps-API

# OvervieW

A self-contained GitOps pipeline running locally on **kind**, provisioned by **Terraform**, delivered by **ArgoCD**, and packaged with **Helm**. It deploys a two-service application — a **FastAPI** REST API and a **React** frontend — behind an nginx ingress.

The flow: *push to Git → ArgoCD detects the change → Helm release syncs → pods roll out.*

---

## Architecture

Each tool owns one concern:

- **Terraform** provisions the infrastructure: the kind cluster, the nginx ingress controller, and ArgoCD.
- **Helm** packages the application (API + frontend + ingress) into one versioned, parameterized chart.
- **ArgoCD** watches Git repo and continuously reconciles the cluster to match the chart.

```
Git repo ──► ArgoCD ──► Helm release ──► Kubernetes (kind)
   ▲                                          │
   └──────────── developer pushes changes ────┘

Terraform ──► kind cluster + nginx ingress + ArgoCD   (one-time bootstrap)
```

Request routing through the ingress:

- `/api/...` → API service (the `/api` prefix is stripped before reaching FastAPI)
- `/` → frontend service

---

## Repository layout

```
gitops-fullstack/
├── terraform/              # cluster + ingress + ArgoCD bootstrap
│   ├── main.tf             # kind cluster, providers
│   ├── ingress.tf          # nginx ingress controller (Helm release)
│   └── argocd.tf           # ArgoCD (Helm release)
├── app/
│   ├── api/                # FastAPI source + Dockerfile
│   └── frontend/           # React source + nginx + Dockerfile
├── charts/
│   └── myapp/              # Helm chart deploying both services
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/      # deployments, services, ingress
└── argocd/
    └── application.yaml    # ArgoCD Application pointing at charts/myapp
```

---

## Prerequisites

| Tool | Purpose |
|---|---|
| Docker | Runs the kind cluster and builds images |
| kind | Local Kubernetes in Docker |
| kubectl | Talk to the cluster |
| Helm | Package/deploy the app |
| Terraform | Provision cluster-level infrastructure |
| Git | Version control |

---

## Setup

### 1. Provision the cluster and platform (Terraform)

```bash
cd terraform
terraform init
terraform apply      # creates kind cluster, nginx ingress, ArgoCD
cd ..
```

Verify:

```bash
kubectl get pods -n argocd
kubectl get pods -n ingress-nginx
```

### 2. Build and load the application images

Images are loaded directly into kind and do not require a registry for local use:

```bash
docker build -t myapp-api:v0.1.0 ./app/api
kind load docker-image myapp-api:v0.1.0 --name gitops

docker build -t myapp-frontend:v0.1.0 ./app/frontend
kind load docker-image myapp-frontend:v0.1.0 --name gitops
```

### 3. Point ArgoCD at your repo

Edit `argocd/application.yaml` and set `repoURL` to the GitHub repository, then commit and push everything:

```bash
git add .
git commit -m "deploy myapp"
git push
```

### 4. Register the application

```bash
kubectl apply -f argocd/application.yaml
```

### 5. Add the ingress host

Map the ingress hostname to localhost.

- **Linux/macOS:** `echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts`
- **Windows (PowerShell as Admin):** `Add-Content C:\Windows\System32\drivers\etc\hosts "127.0.0.1 myapp.local"`

---

### 6. Test the API endpoints

```bash
curl http://myapp.local/api/health     # {"status":"ok"}
curl http://myapp.local/api/items      # list of items
```

Open `http://myapp.local/` in a browser for the frontend, which fetches the item list from the API through the same host.

### 7. Observe application via ArgoCD dashboard

```bash
# Port-forward the UI
kubectl port-forward -n argocd svc/argocd-server 8080:80
# visit http://localhost:8080  (user: admin)
```

Retrieve the initial admin password:

- **Linux/macOS:** `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo`
- **Windows (PowerShell):**
  ```powershell
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}")))
  ```

---

## The GitOps loop

Once running, ArgoCD reconciles the cluster to Git automatically. To ship a change to the Helm chart or app config, edit the files, commit, and push — ArgoCD syncs within a few minutes (or trigger it manually in the UI).

> **Note on images (local vs. true GitOps):** with the local `kind load` approach, ArgoCD syncs manifest changes from Git, but a rebuilt image must still be loaded manually:
> ```bash
> docker build -t myapp-api:v0.1.0 ./app/api
> kind load docker-image myapp-api:v0.1.0 --name gitops
> kubectl rollout restart deployment/api
> ```

---

## Troubleshooting / Lessons Learned

| Problem encountered | Cause | Lesson
|---|---|---|
| `terraform apply` fails at `docker info` | Docker not running | Start Docker Desktop/ Engine; confirm `docker run --rm hello-world` |
| `kubeadm init` fails, kubelet logs mention cgroup v1 | Host on cgroup v1 | Enable cgroup v2 |
| Helm provider syntax errors on `kubernetes`/`set` | v2 vs v3 provider mismatch | Match config to the installed provider; `terraform init -upgrade`; keep `.terraform.lock.hcl` committed |
| Ingress shows `CLASS <none>` | Missing `ingressClassName: nginx` | Add it to the ingress template |
| API call returns frontend HTML | Request didn't match the `/api` rule | Check ingress paths / `use-regex` annotation |
| API 404s (`{"detail":"Not Found"}`) but ingress works | App route path differs from what's forwarded | Align route paths in `main.py` with the ingress rewrite; verify with `/openapi.json` |
| Change didn't take despite ArgoCD "Synced" | ArgoCD deploys Git, not local edits | Confirm with `git show HEAD:<file>`; commit and push |

> A useful debugging trick: `curl http://localhost:8000/openapi.json` (via `kubectl port-forward svc/api 8000:8000`) lists the routes the **running** API actually serves — the fastest way to catch a code/ingress path mismatch.

---

## Stack

Terraform · kind · Helm · ArgoCD · nginx ingress · FastAPI · React · Docker

---

## Future Updates

- Push images to GitHub Container Registry and reference them by tag in `values.yaml`.
- Add a GitHub Actions workflow to build, push, and bump the image tag on each commit.
- Add per-environment values (`values-dev.yaml`, `values-staging.yaml`) and an ArgoCD Application per environment.
- Adopt the app-of-apps pattern.
- Add sealed-secrets or external-secrets for secret management.
