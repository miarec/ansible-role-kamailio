# ansible-role-kamailio

Ansible role to provision Kamailio SIP Proxy application.

The role builds Kamailio from source and installs it into `kamailio_install_dir`
(default `/opt/kamailio`). When `{{ kamailio_install_dir }}/sbin/kamailio` already
exists, the role skips the build and only configures Kamailio. To build again, set
`kamailio_force_install: true`.

Supported platforms: Ubuntu 22.04 (jammy), Ubuntu 24.04 (noble), and Ubuntu 26.04
(resolute).

## Role variables

See `defaults/main.yml` for all variables. The most important ones:

- `kamailio_version`: the Kamailio version to build, a tag of
  https://github.com/kamailio/kamailio.
- `kamailio_config_file_content`: the content of the Kamailio configuration file.
  Required.
- `kamailio_install_dir`: the installation directory (default `/opt/kamailio`).
- `kamailio_include_modules`: extra modules to build (default `tls`).
- `kamailio_source_patches`: patches of `files/patches/` that the role applies to the
  source before it builds it. Each file says why it exists and when to remove it.
  The build fails when a patch doesn't apply to `kamailio_version`, so check each
  patch when you change the version. An empty list builds the release as it is.
  The test images contain the default patches.

## Example playbook

```yaml
- name: Install Kamailio
  hosts: sip
  become: true
  roles:
    - role: kamailio
      kamailio_version: 6.1.5
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
MOLECULE_KAMAILIO_VERSION=6.0.8 uv run molecule test

# Check that Kamailio's log reaches its log file after a run that failed to
# start Kamailio. Uses the Kamailio test image, so it doesn't build Kamailio.
uv run molecule test -s failed-start
```

The Molecule scenarios load the role by path, so the test also works when the role
is checked out under another directory name, for example as `roles/kamailio` in a
playbook repository.

Molecule variables:

| Variable                     | Default      | Description                                                                      |
|------------------------------|--------------|----------------------------------------------------------------------------------|
| `MOLECULE_DISTRO`            | `ubuntu2404` | Container OS: `ubuntu2204`, `ubuntu2404`, or `ubuntu2604`                        |
| `MOLECULE_KAMAILIO_VERSION`  | `6.1.5`      | Value of `kamailio_version`, or the version of the test image in `failed-start` |
| `MOLECULE_ANSIBLE_VERBOSITY` | `0`          | Ansible verbosity, 0-3 (same as `-v`-`-vvv`)                                     |

## Test images

The repository publishes systemd test images with Kamailio already built by this
role's install tasks:

```text
ghcr.io/miarec/kamailio:<kamailio version>-<distribution>
```

For example, `ghcr.io/miarec/kamailio:6.1.5-ubuntu2404`. Each image is multi-arch
(`linux/amd64` and `linux/arm64`) and starts from
`ghcr.io/miarec/<distribution>-systemd`. The per-architecture tags (for example
`6.1.5-ubuntu2404-arm64`) are intermediate build results.

Use the images in tests of playbooks that use this role. When the role runs against a
container from the image, it finds `/opt/kamailio/sbin/kamailio`, skips the build,
and only configures and starts Kamailio. Run the container the same way as the
systemd base image, for example in Molecule:

```yaml
platforms:
  - name: kamailio
    image: ghcr.io/miarec/kamailio:6.1.5-ubuntu2404
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
```

Each version and distribution also has an image built without the role's patches
(`kamailio_source_patches: []`), tagged `<kamailio version>-unpatched-<distribution>`,
for example `ghcr.io/miarec/kamailio:6.1.5-unpatched-ubuntu2604`. A playbook's tests
run it to show what a patch fixes. Build one locally with `IMAGE_VARIANT=unpatched
image/build.sh ...`.

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

The first push of a new image name creates a GHCR package. After the first push,
check that the package is public in its settings, and change its visibility if it
isn't. Public images can be pulled without logging in.

To add a version, add it to `image/versions.json` and merge the change to `master`.
To build a version once without changing the file:

```bash
gh workflow run image.yml -f kamailio_version=6.0.8
```

### Build an image locally

`image/build.sh` starts a container from the systemd base image, runs the role in it
with `image/playbook.yml`, removes the Kamailio configuration, and commits the
container for the architecture of your Docker host. `image/smoke-test.sh` runs the
role against a container from the new image and fails if the role builds Kamailio
again or the service does not start.

```bash
image/build.sh 6.1.5 ubuntu2404 ghcr.io/miarec/kamailio:6.1.5-ubuntu2404
image/smoke-test.sh 6.1.5 ghcr.io/miarec/kamailio:6.1.5-ubuntu2404
```
