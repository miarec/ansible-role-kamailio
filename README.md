# ansible-role-kamailio

Ansible role to provision Kamailio SIP Proxy application.

The role builds Kamailio from source and installs it into `kamailio_install_dir`
(default `/opt/kamailio`). When `{{ kamailio_install_dir }}/sbin/kamailio` already
exists, the role skips the build and only configures Kamailio. To build again, set
`kamailio_force_install: true`.

Supported platforms: Ubuntu 22.04 (jammy) and Ubuntu 24.04 (noble).

## Role variables

See `defaults/main.yml` for all variables. The most important ones:

- `kamailio_version`: the Kamailio version to build, a tag of
  https://github.com/kamailio/kamailio.
- `kamailio_config_file_content`: the content of the Kamailio configuration file.
  Required.
- `kamailio_install_dir`: the installation directory (default `/opt/kamailio`).
- `kamailio_include_modules`: extra modules to build (default `tls`).

## Example playbook

```yaml
- name: Install Kamailio
  hosts: sip
  become: true
  roles:
    - role: kamailio
      kamailio_version: 5.8.3
      kamailio_config_file_content: "{{ lookup('template', 'kamailio.cfg.j2') }}"
```

## Testing

This role uses [Molecule](https://molecule.readthedocs.io/) with Docker for testing.
[uv](https://docs.astral.sh/uv/) manages the Python dependencies (`pyproject.toml`
and `uv.lock`).

### Prerequisites

- Docker
- uv (install with `curl -LsSf https://astral.sh/uv/install.sh | sh`)

### Run the tests

```bash
# Lint
uv run ansible-lint

# Build Kamailio from source in an Ubuntu 24.04 container and test it
uv run molecule test

# Test another distribution or Kamailio version
MOLECULE_DISTRO=ubuntu2204 uv run molecule test
MOLECULE_KAMAILIO_VERSION=5.8.4 uv run molecule test
```

The Molecule scenario loads the role by path, so the test also works when the role
is checked out under another directory name, for example as `roles/kamailio` in a
playbook repository.

Molecule variables:

| Variable                     | Default      | Description                                  |
|------------------------------|--------------|----------------------------------------------|
| `MOLECULE_DISTRO`            | `ubuntu2404` | Container OS: `ubuntu2204` or `ubuntu2404`   |
| `MOLECULE_KAMAILIO_VERSION`  | `5.8.3`      | Value of `kamailio_version`                  |
| `MOLECULE_ANSIBLE_VERBOSITY` | `0`          | Ansible verbosity, 0-3 (same as `-v`-`-vvv`) |

## Test images

The repository publishes systemd test images with Kamailio already built by this
role's install tasks:

```text
ghcr.io/miarec/kamailio:<kamailio version>-<distribution>
```

For example, `ghcr.io/miarec/kamailio:5.8.3-ubuntu2404`. Each image is multi-arch
(`linux/amd64` and `linux/arm64`) and starts from
`ghcr.io/miarec/<distribution>-systemd`. The per-architecture tags (for example
`5.8.3-ubuntu2404-arm64`) are intermediate build results.

Use the images in tests of playbooks that use this role. When the role runs against a
container from the image, it finds `/opt/kamailio/sbin/kamailio`, skips the build,
and only configures and starts Kamailio. Run the container the same way as the
systemd base image, for example in Molecule:

```yaml
platforms:
  - name: kamailio
    image: ghcr.io/miarec/kamailio:5.8.3-ubuntu2404
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
```

The image contains the Kamailio binaries, the `kamailio` user and group, the build
dependencies, and `rsyslog`. It contains no Kamailio configuration, and the
`kamailio` service is not installed until the role runs. Do not use the images in
production: production hosts build Kamailio with the role.

### Versions

`image/versions.json` lists the Kamailio versions and distributions to build. The
`Test images` workflow (`.github/workflows/image.yml`) builds every combination:

- On pull requests, it builds and smoke-tests the images, but does not push them.
- On pushes to `master`, it builds, smoke-tests, and pushes the images.
- When run manually (`workflow_dispatch`) on `master`, it builds and pushes the
  versions in `image/versions.json`, or only the version in the `kamailio_version`
  input. A manual run on another branch builds and smoke-tests, but does not push.

The first push of a new image name creates a private GHCR package; an organization
owner must make it public once in the package settings (Change visibility).

To add a version, add it to `image/versions.json` and merge the change to `master`.
To build a version once without changing the file:

```bash
gh workflow run image.yml -f kamailio_version=5.8.4
```

### Build an image locally

`image/build.sh` starts a container from the systemd base image, runs the role in it
with `image/playbook.yml`, removes the Kamailio configuration, and commits the
container for the architecture of your Docker host. `image/smoke-test.sh` runs the
role against a container from the new image and fails if the role builds Kamailio
again or the service does not start.

```bash
image/build.sh 5.8.3 ubuntu2404 ghcr.io/miarec/kamailio:5.8.3-ubuntu2404
image/smoke-test.sh 5.8.3 ghcr.io/miarec/kamailio:5.8.3-ubuntu2404
```
