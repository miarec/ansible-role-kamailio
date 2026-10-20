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
