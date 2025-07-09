#!/usr/bin/env bash
set -e

# Dify development server installation and deployment script
# Usage: ./install_deploy.sh [--method METHOD] [--target HOST]
# Methods:
#   docker - deploy using docker compose
#   local  - deploy locally using poetry & pnpm
#   ssh    - deploy to remote host via SSH
#   auto   - detect based on available tools (default)

method="auto"
target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method)
      method="$2"; shift 2;;
    --target)
      target="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 [--method METHOD] [--target HOST]"; exit 0;;
    *)
      echo "Unknown option: $1"; exit 1;;
  esac
done

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

validate_docker() {
  check_cmd docker && docker compose version >/dev/null 2>&1
}

validate_ssh() {
  check_cmd ssh
}

validate_poetry() {
  check_cmd poetry
}

deploy_docker() {
  echo "[INFO] Deploying with Docker Compose"
  cd "$(dirname "$0")/docker"
  if [ ! -f .env ]; then
    cp .env.example .env
  fi
  docker compose up -d
  echo "[INFO] Docker deployment finished"
}

deploy_local() {
  echo "[INFO] Deploying locally using Poetry"
  cd "$(dirname "$0")/api"
  if [ ! -f .env ]; then
    cp .env.example .env
  fi
  poetry install
  poetry run python -m flask db upgrade
  poetry run python -m flask run --host 0.0.0.0 --port=5001 --debug &
  cd ../web
  pnpm install
  pnpm run dev &
  echo "[INFO] Local development servers started"
}

deploy_ssh() {
  host="$1"
  if ! validate_ssh; then
    echo "[ERROR] ssh command not found"; exit 1
  fi
  echo "[INFO] Deploying via SSH to $host"
  echo "This section should be customized for your environment."
  echo "For example:" 
  echo "ssh $host 'git clone https://github.com/langgenius/dify.git && cd dify && bash install_deploy.sh --method docker'"
}

if [ "$method" = "auto" ]; then
  if validate_docker; then
    method="docker"
  elif validate_poetry; then
    method="local"
  elif [ -n "$target" ] && validate_ssh; then
    method="ssh"
  else
    echo "[ERROR] Could not determine deployment method"; exit 1
  fi
fi

case "$method" in
  docker)
    deploy_docker;;
  local)
    deploy_local;;
  ssh)
    if [ -z "$target" ]; then
      echo "[ERROR] --target required for ssh method"; exit 1
    fi
    deploy_ssh "$target";;
  *)
    echo "[ERROR] Unknown method: $method"; exit 1;;
esac
