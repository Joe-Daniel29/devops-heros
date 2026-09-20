# DevOps Assignment — Season 1

**Author:** Joe Daniel
**Enrollment:** 24bcs10214
**Course:** SST DevOps & Cloud [SWE]

Assignments covering Linux, shell scripting, networking, Git, Docker and Kubernetes Services. All commands were run on Arch Linux (`joe@archlinux`) with Docker 28.5.1 and Minikube (Kubernetes v1.34.0).

| # | Assignment | Folder | File to submit |
|---|---|---|---|
| 1 | Linux Fundamentals | `linux fundamentals/` | `linux fundamentals/README.md` |
| 2 | Shell Scripting | `shell scripting/` | `shell scripting/README.md` |
| 3 | Networking | `networking fundamentals/` | `networking fundamentals/README.md` |
| 4 | Git and GitHub | `git/` | `git/README.md` |
| 5 | Docker Fundamentals | `docker fundamentals/` | `docker fundamentals/README.md` |
| 6 | Docker Images | `docker and images/` | `docker and images/README.md` |
| 7 | Docker Networking | `docker network/` | `docker network/README.md` |
| 8 | Kubernetes Networking & Services | `kubernetes services/` | `kubernetes services/README.md` |

## What each assignment covers

**Linux Fundamentals** — hard links vs soft links verified by inode and link count, what happens to each when the original is deleted, `adduser` vs `useradd` (demonstrated on Arch, where only `useradd` exists), `journalctl` for service and boot logs, and a command cheat sheet.

**Shell Scripting** — `system-info.sh` using variables, command substitution, `read -p` input, `mkdir`, `touch`, and `>` redirection to capture the process list to a file.

**Networking** — the ten troubleshooting commands (`ping`, `traceroute`, `ss`/`netstat`, `telnet`/`nc`, `tcpdump`, `nslookup`, `dig`, `curl`, `ip`/`arp`, `systemctl`) with real output, what each one proves, and the order to use them in.

**Git and GitHub** — `git commit -m` vs `git commit -a -m` including the untracked-file trap, and `git cherry-pick` moving exactly one commit between branches.

**Docker Fundamentals** — six Hello World web apps (Node.js, Python, Java, Apache, React, Nginx), each with its own Dockerfile, built, run and verified with `curl`.

**Docker Images** — a multi-stage Dockerfile with `builder` and `production` stages, a measured size comparison against the single-stage equivalent, and three language runtimes containerised side by side.

**Docker Networking** — three custom bridge networks demonstrating segmentation, host networking, bind mounts with live updates, and an overlay network on a single-node Swarm.

**Kubernetes Services** — a ClusterIP Service in front of three nginx replicas, accessed by short name, FQDN and ClusterIP from inside the cluster, and proven unreachable from outside it.

Each assignment README embeds terminal screenshots from its own `screenshots/` folder.
