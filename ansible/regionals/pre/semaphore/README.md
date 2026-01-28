# Semaphore UI Ansible Playbook

This playbook deploys [Semaphore UI](https://semaphoreui.com/) - an open-source, modern UI for Ansible.

## Overview

The playbook installs and configures:
- Semaphore UI binary from GitHub releases
- Teleport agent for secure access
- Black-team administrative user
- IT department users

## Supported Operating Systems

- SLES 15.x (openSUSE)
- RHEL/Rocky Linux 8/9
- Debian/Ubuntu

## Variables

### Semaphore Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `semaphore_server_name` | `semaphore` | Server hostname |
| `semaphore_version` | `2.10.43` | Semaphore version to install |
| `semaphore_port` | `3000` | Port for Semaphore web UI |
| `semaphore_user` | `semaphore` | System user for Semaphore |
| `semaphore_group` | `semaphore` | System group for Semaphore |
| `semaphore_config_dir` | `/opt/semaphore` | Configuration directory |
| `semaphore_data_dir` | `/var/lib/semaphore` | Data directory |
| `semaphore_admin_user` | `admin` | Admin username |
| `semaphore_admin_password` | `example-password` | Admin password |
| `semaphore_admin_email` | `admin@placebo-pharma.com` | Admin email |

### Teleport Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `teleport_proxy_server` | `teleport.placebo-pharma.com:443` | Teleport proxy server address |
| `teleport_token` | `SEMAPHORE_JOIN_TOKEN` | Teleport join token |

## Usage

### Prerequisites

1. Add the semaphore host to the inventory file (`inventory/0-inventory.yaml`):

```yaml
semaphore:
  hosts:
    10.37.32.XX:
      ansible_user: semaphore
      ansible_ssh_private_key_file: ../../../../documentation/black_team/black-team
      team: 2
      dns_server_override: "10.37.1.1"
      search_domain_override: "proxmox.internal"
  vars:
    hostname: semaphore
```

2. Update the global inventory file (`inventory/1-global.yaml`) to include semaphore in the linux group if needed.

### Run the Playbook

Full installation:
```bash
ansible-playbook -i inventory/ pre/semaphore/playbook.yaml
```

Run specific tags:
```bash
# Only install Semaphore
ansible-playbook -i inventory/ pre/semaphore/playbook.yaml --tags semaphore

# Only configure Teleport
ansible-playbook -i inventory/ pre/semaphore/playbook.yaml --tags teleport

# Only setup black-team user
ansible-playbook -i inventory/ pre/semaphore/playbook.yaml --tags black-team
```

## File Structure

```
semaphore/
├── playbook.yaml           # Main playbook
├── README.md               # This file
├── tasks/
│   ├── semaphore.yaml      # Semaphore installation tasks
│   └── teleport.yaml       # Teleport installation tasks
├── templates/
│   ├── config.json.j2      # Semaphore configuration template
│   ├── semaphore.service.j2 # Systemd service template
│   └── teleport.yaml.j2    # Teleport configuration template
└── files/                  # Static files (if any)
```

## Access

After deployment:
- **Semaphore UI**: http://semaphore-ip:3000
- **Teleport**: Access through Teleport proxy as application `semaphore`

## Teleport Integration

The playbook configures Teleport to:
- Register the node with SSH access (label: `service=semaphore`)
- Expose Semaphore UI as a Teleport application (accessible via `https://semaphore.teleport.placebo-pharma.com`)

## Notes

- The playbook uses SQLite as the database backend (suitable for single-node deployments)
- For production with multiple nodes, consider using PostgreSQL or MySQL backend
- Cookie secrets are randomly generated during deployment
- TOTP (2FA) is enabled by default
