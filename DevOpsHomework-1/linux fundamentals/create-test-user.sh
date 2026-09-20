#!/usr/bin/env bash
# Task 2 + 3 helper — run on Ubuntu/Debian with sudo.
# Creates hwtest with adduser (preferred), then shows journalctl usage.

set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script must run on Linux (Ubuntu/Debian). This machine is $(uname -s)."
  exit 1
fi

if ! command -v adduser >/dev/null; then
  echo "adduser not found. Install the 'adduser' package (Debian/Ubuntu)."
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Re-run with sudo: sudo $0"
  exit 1
fi

USERNAME="${1:-hwtest}"

if id "$USERNAME" >/dev/null 2>&1; then
  echo "User $USERNAME already exists."
else
  echo "Creating $USERNAME with adduser (Ubuntu preferred)..."
  adduser --disabled-password --gecos "Linux Homework Test User" "$USERNAME"
fi

echo
echo "===== user info ====="
id "$USERNAME"
getent passwd "$USERNAME"
ls -ld "/home/$USERNAME"

echo
echo "===== adduser vs useradd ====="
echo "adduser : $(command -v adduser)  (Debian helper — use this on Ubuntu)"
echo "useradd : $(command -v useradd)  (low-level; needs -m to create home)"

echo
echo "===== journalctl: ssh service (last 20 lines) ====="
if command -v journalctl >/dev/null; then
  journalctl -u ssh -n 20 --no-pager || journalctl -u sshd -n 20 --no-pager || true
  echo
  echo "===== journalctl: this boot, errors ====="
  journalctl -b -p err -n 20 --no-pager || true
else
  echo "journalctl not found (no systemd?)"
fi

echo
echo "Done. Remove the user later with: sudo deluser --remove-home $USERNAME"
