# Falco Installation and Configuration

This playbook installs and configures Falco runtime security monitoring with Falcosidekick for alert forwarding.

## What Rules Were Set Up?

Based on the referenced Falco machine configuration:

1. **Default Falco Rules** (`falco_rules.yaml`):
   - Uses the standard Falco ruleset from the official Falco repository
   - Includes rules for detecting:
     - Sensitive file access (e.g., `/etc/shadow`, `/etc/sudoers`)
     - Shell spawning from untrusted processes
     - Container escape attempts
     - Network anomalies
     - Process injection
     - Fileless execution
     - And many more security events

2. **Custom Rules** (`falco_rules.local.yaml`):
   - Currently empty (just a placeholder comment)
   - This is where you can add custom rules specific to your environment

## Configuration Summary

The playbook configures Falco with the following settings:

### Engine Configuration
- **Engine Type**: `modern_ebpf` (Modern eBPF driver)
- **Buffer Size**: 4 (8 MB per CPU)
- **CPUs per Buffer**: 2

### Output Configuration
- **JSON Output**: Enabled
- **Syslog Output**: Enabled
- **HTTP Output**: Enabled (sends to Falcosidekick at `http://localhost:2801`)
- **Priority Level**: `debug` (captures all rule priorities)

### Web Server
- **Enabled**: Yes
- **Port**: 8765
- **Prometheus Metrics**: Enabled
- **Health Check Endpoint**: `/healthz`

### Metrics
- **Enabled**: Yes
- **Interval**: 1 hour
- **Output Rule**: Enabled (emits metrics as Falco alerts)

### Falcosidekick
- **Installation**: Binary installation (not Docker)
- **Binary Location**: `/usr/local/bin/falcosidekick`
- **Config Location**: `/etc/falcosidekick/config.yaml`
- **HTTP Port**: 2801 (receives alerts from Falco)

## Services

The playbook sets up the following systemd services:

1. **falco-modern-bpf.service**: Main Falco daemon with modern eBPF driver
2. **falcosidekick.service**: Alert forwarding service (Docker Compose)
3. **falcoctl-artifact-follow.service**: Automatic rule updates

## Usage

### Running the Playbook

```bash
# Run the complete playbook
ansible-playbook -i inventory.ini ansible/regionals/pre/falco/playbook.yaml

# Run specific tags
ansible-playbook -i inventory.ini ansible/regionals/pre/falco/playbook.yaml --tags falco
ansible-playbook -i inventory.ini ansible/regionals/pre/falco/playbook.yaml --tags falcosidekick
ansible-playbook -i inventory.ini ansible/regionals/pre/falco/playbook.yaml --tags config
```

### Inventory Requirements

Ensure your inventory file includes a `[falco]` group with the target hosts:

```ini
[falco]
falco-host ansible_host=10.0.0.10
```

### Customization

You can customize the configuration by modifying the variables in `playbook.yaml`:

```yaml
vars:
  falco_version: "0.42.1"
  falco_engine_kind: "modern_ebpf"
  falco_priority: "debug"
  falco_http_output_url: "http://localhost:2801"
  falcosidekick_ui_user: "falco"
  falcosidekick_ui_password: "example-password"
```

### Adding Custom Rules

1. Create custom rules in `/etc/falco/falco_rules.local.yaml` on the target host
2. Or modify the playbook to copy your custom rules file
3. Restart Falco: `systemctl restart falco-modern-bpf`

### Verifying Installation

```bash
# Check Falco service status
systemctl status falco-modern-bpf

# Check Falcosidekick service status
systemctl status falcosidekick

# View Falco logs
journalctl -u falco-modern-bpf -f

# Test Falco web server
curl http://localhost:8765/healthz

# Access Falcosidekick UI
curl http://localhost:2802
```

## File Structure

```
ansible/regionals/pre/falco/
├── playbook.yaml                    # Main playbook
├── README.md                        # This file
├── handlers/
│   └── main.yaml                    # Service restart handlers
├── tasks/
│   ├── install_falco.yaml          # Falco package installation
│   ├── configure_falco.yaml        # Falco configuration
│   ├── install_falcosidekick.yaml  # Falcosidekick setup
│   └── services.yaml               # Systemd service management
└── templates/
    ├── falco.yaml.j2               # Falco main config template
    ├── config.yaml.j2              # Falcosidekick config template
    └── falcosidekick.service.j2    # Falcosidekick systemd service
```

## Dependencies

- Ansible 2.9+
- Target hosts must be Debian/Ubuntu-based or Rocky Linux 9.4+ (RPM-based)
- Root or sudo access on target hosts
- Internet access to download Falcosidekick binary from GitHub releases
- EPEL repository (automatically installed for Rocky Linux)

## Notes

- The playbook copies rules files from `ansible/regionals/pre/falco/file/` directory
- If source rules files don't exist, it will create an empty `falco_rules.local.yaml`
- Falcosidekick is installed as a binary (not Docker) to match the original setup
- The modern eBPF driver requires a kernel version >= 5.8
- The falcosidekick service matches the original systemd service file exactly
