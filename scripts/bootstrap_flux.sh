#!/bin/bash
set -e

GITHUB_USER=$1
GIT_REPO=$2

if [ -z "$GITHUB_USER" ] || [ -z "$GIT_REPO" ]; then
  echo "Usage: bootstrap_flux.sh <github-username> <git-repo-name>"
  exit 1
fi

echo "Bootstrapping FluxCD to GitHub repo $GITHUB_USER/$GIT_REPO"

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GIT_REPO \
  --branch=main \
  --path=clusters/prod/ \
  --personal

