#!/usr/bin/env bash
# Run the role against a container from a Kamailio test image and check that
# the role skips the build, configures Kamailio, and starts the service.
#
# Usage: image/smoke-test.sh KAMAILIO_VERSION IMAGE_TAG
#   image/smoke-test.sh 5.8.3 ghcr.io/miarec/kamailio:5.8.3-ubuntu2404
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 KAMAILIO_VERSION IMAGE_TAG" >&2
    exit 2
fi

version=$1
tag=$2

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
container="kamailio-image-smoke-${version}-$$"
log=$(mktemp)

cleanup() {
    docker rm --force --volumes "$container" >/dev/null 2>&1 || true
    rm -f "$log"
}
trap cleanup EXIT

docker run --detach --name "$container" \
    --privileged --cgroupns host \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:rw \
    "$tag"

start=$(date +%s)
(
    cd "$repo_dir"
    uv run ansible-playbook image/playbook.yml \
        --inventory "${container}," \
        --connection community.docker.docker \
        --extra-vars "kamailio_version=${version} kamailio_image_prebuilt=true"
) 2>&1 | tee "$log"
echo "Role converge from the image took $(($(date +%s) - start)) s"

# The playbook asserts that the role found the binary. Also check the log, in
# case the role changes how it decides to build.
if grep -q "Compile Kamailio" "$log"; then
    echo "The role compiled Kamailio, but the image should contain it" >&2
    exit 1
fi

docker exec "$container" systemctl is-active kamailio
echo "Smoke test passed for $tag"
