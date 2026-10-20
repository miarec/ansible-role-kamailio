#!/usr/bin/env bash
# Build a Kamailio test image with the role's own install tasks.
#
# Usage: image/build.sh KAMAILIO_VERSION DISTRO IMAGE_TAG
#   image/build.sh 5.8.3 ubuntu2404 ghcr.io/miarec/kamailio:5.8.3-ubuntu2404
#
# The script starts a container from ghcr.io/miarec/DISTRO-systemd, runs the
# role in it (the role builds Kamailio from source), removes the Kamailio
# configuration, and commits the container as IMAGE_TAG for the native
# architecture of the Docker host.
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 KAMAILIO_VERSION DISTRO IMAGE_TAG" >&2
    exit 2
fi

version=$1
distro=$2
tag=$3

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
base_image="ghcr.io/miarec/${distro}-systemd:latest"
source_url=${IMAGE_SOURCE:-https://github.com/miarec/ansible-role-kamailio}
revision=${IMAGE_REVISION:-$(git -C "$repo_dir" rev-parse HEAD)}
container="kamailio-image-build-${version}-${distro}-$$"

cleanup() {
    docker rm --force --volumes "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker pull "$base_image"

# The same container options as the Molecule scenario. SIGRTMIN+3 makes
# systemd shut down cleanly on "docker stop".
docker run --detach --name "$container" \
    --privileged --cgroupns host \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --stop-signal SIGRTMIN+3 \
    "$base_image"

start=$(date +%s)
(
    cd "$repo_dir"
    uv run ansible-playbook image/playbook.yml \
        --inventory "${container}," \
        --connection community.docker.docker \
        --extra-vars "kamailio_version=${version} kamailio_image_build=true"
)
echo "Role converge from scratch took $(($(date +%s) - start)) s"

docker exec "$container" rm -rf /root/.ansible
docker stop "$container"

docker commit \
    --change 'CMD ["/lib/systemd/systemd"]' \
    --change "LABEL org.opencontainers.image.title=kamailio" \
    --change "LABEL org.opencontainers.image.description=\"Kamailio ${version} built by ansible-role-kamailio on ${distro}, for tests\"" \
    --change "LABEL org.opencontainers.image.version=${version}" \
    --change "LABEL org.opencontainers.image.source=${source_url}" \
    --change "LABEL org.opencontainers.image.revision=${revision}" \
    --change "LABEL org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --change "LABEL org.opencontainers.image.base.name=${base_image}" \
    "$container" "$tag"

echo "Built $tag"
