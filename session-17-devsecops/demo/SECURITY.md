# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Security Controls in the Pipeline

Every push and pull request to `main` runs `.github/workflows/devsecops.yml`.
An image is only pushed to GHCR and deployed when **all** checks pass.

| Control | Tool | Configuration | Gate |
|---------|------|---------------|------|
| SAST | GitHub CodeQL (`python`) | default query suite | alerts in the Security tab |
| SAST | Bandit | `bandit.yaml` | fails on MEDIUM / HIGH |
| SCA | pip-audit | `requirements.txt`, `requirements-dev.txt` | fails on any known vulnerability |
| Secret scanning | Gitleaks | `.gitleaks.toml` (default rules) | fails on any leak |
| Image scanning | Trivy | `trivy.yaml`, `.trivyignore` | fails on fixable HIGH / CRITICAL |
| Security gate | `security-gate` job | `if: always()` + `needs` results | blocks push and deploy |

Runtime hardening: non-root container user (`uid 10001`), Flask debug mode off
by default, `allowPrivilegeEscalation: false`, resource limits and health probes
in `k8s/deployment.yaml`.

## Reporting a Vulnerability

Please do **not** open a public issue for security problems.
Use GitHub's **Security → Report a vulnerability** (private advisory) on this
repository. You can expect an acknowledgement within 3 working days and a fix or
mitigation plan within 14 days for confirmed HIGH / CRITICAL issues.

If a credential is ever committed by mistake, treat it as compromised:
revoke / rotate it first, then remove it from the code and history.
