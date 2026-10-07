# Session 17 — Complete CI/CD & DevSecOps

**Author:** Joe Daniel
**Enrollment:** 24bcs10214
**Course:** SST DevOps & Cloud [SWE]
**Manifests:** `session-17-devsecops/`

A Flask application pushed through a nine-stage DevSecOps pipeline. Security checks are not a final review step — they are **gates** wired into the pipeline so that a failing check stops the release before an image is ever published.

Run on Arch Linux with Python 3.12, Docker 28.5.1, Trivy 0.58, Bandit 1.8, Gitleaks 8.21 and Minikube (Kubernetes v1.34.0).

---

## Pipeline flow

```text
┌──────────────┐
│  Build+Test  │  pytest + coverage
└──────┬───────┘
       ├────────────┬─────────────┬──────────────────┐
       ▼            ▼             ▼                  │  (run in parallel)
   ┌────────┐  ┌─────────┐  ┌────────────┐           │
   │  SAST  │  │   SCA   │  │  Secrets   │           │
   │ Bandit │  │pip-audit│  │  Gitleaks  │           │
   └────┬───┘  └────┬────┘  └─────┬──────┘           │
        └───────────┴─────────────┴──────────────────┘
                          ▼
                  ┌───────────────┐
                  │ Docker Build  │
                  └───────┬───────┘
                          ▼
                  ┌───────────────┐
                  │ Trivy Image   │  HIGH/CRITICAL → exit 1
                  └───────┬───────┘
                          ▼
                  ┌───────────────┐
                  │ SECURITY GATE │  ← all must be green
                  └───────┬───────┘
                          ▼
              ┌───────────┴───────────┐
              ▼                       ▼
        ┌───────────┐          ┌─────────────┐
        │ Push GHCR │          │   Deploy    │
        └───────────┘          └─────────────┘
```

The three static checks run **in parallel** — they are independent and this keeps the feedback loop short. Everything after the gate is serialised, because publishing and deploying must not happen on a failed scan.

---

## Project structure

```text
demo/
├── app/
│   ├── app.py              # Flask app: pages + /health + /api/*
│   ├── templates/
│   └── static/
├── tests/test_app.py
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml        # NodePort 30001
├── Dockerfile              # non-root user, python:3.12-slim
├── bandit.yaml             # SAST config
├── .gitleaks.toml          # secret-scanning rules
├── trivy.yaml              # image-scanning config
├── .trivyignore
├── SECURITY.md
└── .github/workflows/devsecops.yml
```

---

## Stage 1: Build & Unit Tests

```bash
pip install -r requirements.txt -r requirements-dev.txt
pytest -v --cov=app --cov-report=term-missing
```

![pytest with coverage](./screenshots/01-pytest-coverage.png)

Eight tests, 92% coverage. Coverage is reported but **not** gated — a coverage threshold that blocks merges tends to produce tests written to satisfy the number rather than to catch bugs. The security checks below are gated; coverage is informational.

---

## Stage 2: SAST — Static Application Security Testing

SAST reads **your source code** for dangerous patterns, without running it.

### 2.1 The gate fails: Flask debug mode

```bash
bandit -c bandit.yaml -r app/
```

![Bandit finds B201](./screenshots/02-bandit-sast-fail.png)

```text
>> Issue: [B201:flask_debug_true] A Flask app appears to be run with debug=True,
   which exposes the Werkzeug debugger and allows the execution of arbitrary code.
   Severity: High   Confidence: Medium
   CWE: CWE-94
   Location: app/app.py:142:4
```

This is a genuinely serious finding, not a style nit. Werkzeug's debugger exposes an interactive Python console on the error page — anyone who can trigger an exception on a public instance gets remote code execution.

Note `echo $?` returns **1**. That non-zero exit is the entire mechanism: CI treats a failed command as a failed job.

### 2.2 Fix and pass

```bash
# app.run(host="0.0.0.0", port=5001, debug=False)
bandit -c bandit.yaml -r app/
```

![Bandit passes](./screenshots/03-bandit-sast-pass.png)

---

## Stage 3: SCA — Software Composition Analysis

SCA checks your **dependencies** against vulnerability databases. Most of a modern application is third-party code, so this usually finds more than SAST.

```bash
pip-audit -r requirements.txt
```

![pip-audit](./screenshots/04-pip-audit-sca.png)

```text
Name  Version  ID                  Fix Versions
----- -------- ------------------- ------------
flask 3.0.0    GHSA-m2qf-hxjv-5gpq 3.0.1
```

Pinning Flask to `3.1.3` clears it. The useful detail is the **Fix Versions** column — SCA tools tell you the minimum safe version, which turns "you have a vulnerability" into a one-line change.

This is also the argument for pinning exact versions in `requirements.txt`: an unpinned dependency means the scan result is only valid for whichever version happened to install that day.

---

## Stage 4: Secret Scanning

```bash
echo 'AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE' >> app/config_demo.py
gitleaks detect --source . --config .gitleaks.toml --no-git -v
```

![Gitleaks finds the planted key](./screenshots/05-gitleaks-leak-found.png)

```text
Finding:  AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
Secret:   AKIAIOSFODNN7EXAMPLE
RuleID:   aws-access-token
Entropy:  3.521928
File:     app/config_demo.py
```

The key is AWS's published example value, so nothing real was exposed. Gitleaks matched it on the `AKIA` prefix pattern plus an entropy check — pattern alone would flag too much, entropy alone would flag random-looking non-secrets.

### 4.1 Fix and pass

```bash
rm app/config_demo.py
gitleaks detect --source . --config .gitleaks.toml --no-git -v
```

![Gitleaks clean](./screenshots/06-gitleaks-clean.png)

> **Important caveat:** deleting the file only fixes the working tree. If a real secret had been *committed*, it would still be in git history and recoverable — the only correct response is to **rotate the credential**, then clean history. Scanning with `--no-git` checks the current files; dropping that flag scans all 23 commits.

---

## Stage 5: Docker Build

```bash
docker build -t session17-python:local .
docker run --rm session17-python:local id
```

![docker build](./screenshots/07-docker-build.png)

```text
uid=10001(appuser) gid=10001(appuser) groups=10001(appuser)
```

The Dockerfile creates an unprivileged user and switches to it with `USER appuser`. Containers run as root by default, and a container escape as root is far more damaging than as uid 10001. This is the single highest-value line in most Dockerfiles.

---

## Stage 6 & 7: Container Image Scanning and the Security Gate

Trivy scans the **built image** — the OS packages from the base image, not just your code. This catches an entire class of problem the earlier stages cannot see.

### 7.1 The gate blocks the release

The Dockerfile was originally pinned to `python:3.12.3-slim` (Debian 12.5):

```bash
trivy image --severity HIGH,CRITICAL --exit-code 1 session17-python:old
```

![Trivy gate fails locally](./screenshots/08-trivy-gate-fail.png)

```text
session17-python:old (debian 12.5)
Total: 9 (HIGH: 8, CRITICAL: 1)

libexpat1  CVE-2024-45491  CRITICAL
libkrb5-3  CVE-2024-37370  HIGH
libc6      CVE-2024-33599  HIGH
libssl3    CVE-2024-5535   HIGH
```

**None of these CVEs are in the application code.** They are all in base-image OS libraries. The application was perfectly clean through SAST, SCA and secret scanning, and still could not ship.

In the pipeline, this blocked run #6:

![Run #6 blocked](./screenshots/10-actions-run-blocked.png)

```text
✓ Build & Unit Tests          ✓ Docker Build
✓ SAST (Bandit + CodeQL)      ✗ Container Image Scan (Trivy)
✓ SCA (pip-audit)             - Security Gate         (skipped)
✓ Secret Scanning             - Push to GHCR          (skipped)
                              - Deploy to Kubernetes  (skipped)
```

![Run #6 Trivy job log](./screenshots/11-actions-job-image-scan-failed.png)

Five jobs green, one red, and the three that actually *release* software never ran. Nothing was pushed to GHCR; nothing was deployed.

### 7.2 Fix: move to the maintained base image

```bash
# FROM python:3.12-slim   (Debian 13 "trixie")
trivy image --severity HIGH,CRITICAL --exit-code 1 session17-python:local
```

![Trivy gate passes](./screenshots/09-trivy-gate-pass.png)

```text
session17-python:local (debian 13.1)
Total: 0 (HIGH: 0, CRITICAL: 0)
```

The fix was a one-line base-image change — a reminder that **pinning a patch version of a base image is a liability**, not a safety measure. Pinning `3.12.3-slim` froze the OS packages at their 2024 state while CVEs accumulated against them. Tracking `3.12-slim` keeps receiving security updates.

### 7.3 Run #7 — full pipeline green

![Run #7 success](./screenshots/12-actions-run-success.png)

![Run #7 Trivy job log](./screenshots/13-actions-job-image-scan-passed.png)

The gate job aggregates the four security results and only then allows the release:

```text
SAST:    pass
SCA:     pass
Secrets: pass
Image:   pass
All checks green - release allowed.
```

---

## Stage 8: Push image to GHCR

![Push to GHCR](./screenshots/14-actions-job-push-ghcr.png)

```text
sha-7b2d9e4: digest: sha256:9e3a0c7b14f82d56a0c4b8e2d9f71a35
latest:      digest: sha256:9e3a0c7b14f82d56a0c4b8e2d9f71a35
```

Both tags point at the same digest. The commit-SHA tag is what makes a deployed container traceable; `latest` is a convenience that should never be used in a production manifest, because it is mutable.

Authentication uses the built-in `GITHUB_TOKEN` — no long-lived personal access token needs to exist.

---

## Stage 9: Deploy to Kubernetes

### 9.1 In the pipeline (kind cluster on the runner)

![Deploy job](./screenshots/15-actions-job-deploy.png)

The pipeline spins up a disposable `kind` cluster, loads the scanned image, applies the manifests, waits for the rollout and runs a smoke test against `/health`. A deploy step that does not verify anything is just an `apply` with extra confidence.

### 9.2 On the local Minikube cluster

```bash
kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl rollout status deployment/session17-python
kubectl get deploy,svc,pods -l app=session17-python
```

![kubectl deploy on minikube](./screenshots/16-kubectl-deploy-minikube.png)

The `securityContext` carries the non-root guarantee into the cluster:

```text
{"runAsNonRoot":true,"runAsUser":10001}
```

Setting `USER` in the Dockerfile is a default that a manifest can override; `runAsNonRoot: true` in the PodSpec makes the kubelet **refuse to start** a container that would run as root. Defence in depth — the image says what it wants, the cluster enforces it.

### 9.3 Verify the application

```bash
curl -s http://$(minikube ip):30001/health
curl -s http://$(minikube ip):30001/api/status
```

![curl the app](./screenshots/17-app-access.png)

![/api endpoints](./screenshots/18-app-api-status.png)

---

## Required secrets / settings

| Secret | Used by | Purpose |
|---|---|---|
| `GITHUB_TOKEN` | Push to GHCR | Built in; no manual setup |
| `packages: write` permission | Push to GHCR | Workflow `permissions:` block |
| `security-events: write` | Trivy SARIF upload | Publishes findings to the Security tab |

---

## Deliverables checklist

- [x] Unit tests with coverage reporting
- [x] SAST (Bandit) — failing finding, fixed, passing
- [x] SCA (pip-audit) — vulnerable dependency found and bumped
- [x] Secret scanning (Gitleaks) — planted key caught, removed
- [x] Docker image built, running as non-root
- [x] Container scanning (Trivy) — HIGH/CRITICAL gate
- [x] Gate demonstrated **blocking** a release (run #6)
- [x] Gate demonstrated **allowing** a release (run #7)
- [x] Image pushed to GHCR with SHA and latest tags
- [x] Deployed in-pipeline (kind) and locally (minikube)
- [x] Application verified over HTTP

---

## Notes & learnings

1. **A security gate is just a non-zero exit code.** Every tool here fails the job the same way; nothing is magic.
2. **Clean code is not a clean image.** Run #6 passed every source-level check and still failed on base-image CVEs. Scan the artifact you actually ship.
3. **Pinning a patch version of a base image is a liability.** `3.12.3-slim` froze the OS at its CVEs; `3.12-slim` keeps getting fixes.
4. **Run the cheap checks in parallel, gate once.** SAST, SCA and secret scanning are independent and fast; serialising them wastes minutes on every push.
5. **Deleting a leaked secret is not remediation — rotation is.** Git history keeps what you committed.
6. **Non-root belongs in both the image and the PodSpec.** `USER` is a default; `runAsNonRoot` is enforcement.
7. **Tag images by commit SHA.** `latest` cannot tell you what is running.
