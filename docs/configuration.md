# Configuration Guide

This guide explains all available configuration options for the Clawdbot Ansible installer.

## Configuration File

All default variables are defined in:
**[`roles/clawdbot/defaults/main.yml`](../roles/clawdbot/defaults/main.yml)**

## How to Configure

### Method 1: Command Line Variables

Pass variables directly via `-e` flag:

```bash
ansible-playbook playbook.yml --ask-become-pass \
  -e clawdbot_install_mode=development \
  -e "clawdbot_ssh_keys=['ssh-ed25519 AAAAC3... user@host']"
```

### Method 2: Variables File

Create a `vars.yml` file:

```yaml
# vars.yml
clawdbot_install_mode: development
clawdbot_ssh_keys:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxxxxxxxx user@host"
  - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB... admin@laptop"
clawdbot_repo_url: "https://github.com/YOUR_USERNAME/clawdbot.git"
clawdbot_repo_branch: "main"
tailscale_authkey: "tskey-auth-xxxxxxxxxxxxx"
nodejs_version: "22.x"
```

Then use it:

```bash
ansible-playbook playbook.yml --ask-become-pass -e @vars.yml
```

### Method 3: Edit Defaults

Directly edit `roles/clawdbot/defaults/main.yml` before running the playbook.

**Note**: This is not recommended for version control, use variables files instead.

## Available Variables

### User Configuration

#### `clawdbot_user`
- **Type**: String
- **Default**: `clawdbot`
- **Description**: System user name for running Clawdbot
- **Example**:
  ```bash
  -e clawdbot_user=myuser
  ```

#### `clawdbot_home`
- **Type**: String
- **Default**: `/home/clawdbot`
- **Description**: Home directory for the clawdbot user
- **Example**:
  ```bash
  -e clawdbot_home=/home/myuser
  ```

#### `clawdbot_ssh_keys`
- **Type**: List of strings
- **Default**: `[]` (empty)
- **Description**: SSH public keys for accessing the clawdbot user account
- **Example**:
  ```yaml
  clawdbot_ssh_keys:
    - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxxxxxxxx user@host"
    - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB... admin@laptop"
  ```
  ```bash
  -e "clawdbot_ssh_keys=['ssh-ed25519 AAAAC3... user@host']"
  ```

### Installation Mode

#### `clawdbot_install_mode`
- **Type**: String (`release` or `development`)
- **Default**: `release`
- **Description**: Installation mode
  - `release`: Install via npm (`pnpm install -g clawdbot@latest`)
  - `development`: Clone repo, build from source, symlink binary
- **Example**:
  ```bash
  -e clawdbot_install_mode=development
  ```

### Development Mode Settings

These variables only apply when `clawdbot_install_mode: development`

#### `clawdbot_repo_url`
- **Type**: String (Git URL)
- **Default**: `https://github.com/clawdbot/clawdbot.git`
- **Description**: Git repository URL to clone
- **Example**:
  ```bash
  -e clawdbot_repo_url=https://github.com/YOUR_USERNAME/clawdbot.git
  ```

#### `clawdbot_repo_branch`
- **Type**: String
- **Default**: `main`
- **Description**: Git branch to checkout
- **Example**:
  ```bash
  -e clawdbot_repo_branch=feature-branch
  ```

#### `clawdbot_code_dir`
- **Type**: String (Path)
- **Default**: `{{ clawdbot_home }}/code`
- **Description**: Directory where code repositories are stored
- **Example**:
  ```bash
  -e clawdbot_code_dir=/home/clawdbot/projects
  ```

#### `clawdbot_repo_dir`
- **Type**: String (Path)
- **Default**: `{{ clawdbot_code_dir }}/clawdbot`
- **Description**: Full path to clawdbot repository
- **Example**:
  ```bash
  -e clawdbot_repo_dir=/home/clawdbot/projects/clawdbot
  ```

### Clawdbot Settings

#### `clawdbot_port`
- **Type**: Integer
- **Default**: `3000`
- **Description**: Port for Clawdbot gateway (currently informational)
- **Example**:
  ```bash
  -e clawdbot_port=8080
  ```

#### `clawdbot_config_dir`
- **Type**: String (Path)
- **Default**: `{{ clawdbot_home }}/.clawdbot`
- **Description**: Clawdbot configuration directory
- **Example**:
  ```bash
  -e clawdbot_config_dir=/etc/clawdbot
  ```

### Node.js Configuration

#### `nodejs_version`
- **Type**: String
- **Default**: `22.x`
- **Description**: Node.js major version to install
- **Example**:
  ```bash
  -e nodejs_version=20.x
  ```

### Tailscale Configuration

#### `tailscale_enabled`
- **Type**: Boolean
- **Default**: `false`
- **Description**: Enable Tailscale installation and configuration
- **Example**:
  ```bash
  -e tailscale_enabled=true
  ```
- **Note**: When disabled (default), Tailscale will not be installed, no firewall rules will be added for port 41641, and no Tailscale sudoers entries will be created

#### `tailscale_authkey`
- **Type**: String
- **Default**: `""` (empty - manual setup required)
- **Description**: Tailscale authentication key for automatic connection
- **Security**: Tasks using this variable must set `no_log: true`
- **Example**:
  ```bash
  -e tailscale_authkey=tskey-auth-k1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6
  ```
- **Get Key**: https://login.tailscale.com/admin/settings/keys
- **Note**: Only used when `tailscale_enabled: true`

## Configuration Examples

### Basic Setup with SSH Keys

```yaml
# vars.yml
clawdbot_ssh_keys:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxxxxxxxx user@desktop"
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHyyyyyyyy user@laptop"
```

```bash
ansible-playbook playbook.yml --ask-become-pass -e @vars.yml
```

### Development Setup

```yaml
# vars-dev.yml
clawdbot_install_mode: development
clawdbot_repo_url: "https://github.com/myorg/clawdbot.git"
clawdbot_repo_branch: "develop"
clawdbot_ssh_keys:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxxxxxxxx dev@workstation"
```

```bash
ansible-playbook playbook.yml --ask-become-pass -e @vars-dev.yml
```

### Production Setup with Tailscale

```yaml
# vars-prod.yml
clawdbot_install_mode: release
tailscale_enabled: true
tailscale_authkey: "tskey-auth-k1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6"
clawdbot_ssh_keys:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxxxxxxxx admin@mgmt-server"
nodejs_version: "22.x"
```

```bash
ansible-playbook playbook.yml --ask-become-pass -e @vars-prod.yml
```

### Custom User and Directories

```yaml
# vars-custom.yml
clawdbot_user: mybot
clawdbot_home: /opt/mybot
clawdbot_config_dir: /etc/mybot
clawdbot_code_dir: /opt/mybot/repositories
```

```bash
ansible-playbook playbook.yml --ask-become-pass -e @vars-custom.yml
```

### Testing Different Branches

```yaml
# vars-testing.yml
clawdbot_install_mode: development
clawdbot_repo_branch: "experimental-feature"
clawdbot_ssh_keys:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxxxxxxxx tester@qa"
```

```bash
ansible-playbook playbook.yml --ask-become-pass -e @vars-testing.yml
```

## Environment-Specific Configurations

### Development Environment

```yaml
# environments/dev.yml
clawdbot_install_mode: development
clawdbot_repo_url: "https://github.com/clawdbot/clawdbot.git"
clawdbot_repo_branch: "main"
clawdbot_ssh_keys:
  - "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
```

### Staging Environment

```yaml
# environments/staging.yml
clawdbot_install_mode: release
tailscale_enabled: true
tailscale_authkey: "{{ lookup('env', 'TAILSCALE_AUTHKEY_STAGING') }}"
clawdbot_ssh_keys:
  - "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
```

### Production Environment

```yaml
# environments/prod.yml
clawdbot_install_mode: release
tailscale_enabled: true
tailscale_authkey: "{{ lookup('env', 'TAILSCALE_AUTHKEY_PROD') }}"
clawdbot_ssh_keys:
  - "ssh-ed25519 AAAAC3... ops@prod-mgmt"
  - "ssh-ed25519 AAAAC3... admin@backup-server"
nodejs_version: "22.x"
```

## Security Best Practices

### SSH Keys

1. **Use dedicated keys**: Create separate SSH keys for Clawdbot access
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/clawdbot_ed25519 -C "clawdbot-access"
   ```

2. **Limit key permissions**: Use SSH key options to restrict access
   ```
   from="192.168.1.0/24" ssh-ed25519 AAAAC3... admin@trusted-network
   ```

3. **Rotate keys regularly**: Update SSH keys periodically
   ```bash
   ansible-playbook playbook.yml --ask-become-pass \
     -e "clawdbot_ssh_keys=['$(cat ~/.ssh/new_key.pub)']"
   ```

### Tailscale Auth Keys

1. **Use ephemeral keys** for temporary access
2. **Set expiration times** for auth keys
3. **Use reusable keys** only for automation
4. **Store in secrets manager**: Don't commit to git
   ```bash
   # Use environment variable
   export TAILSCALE_AUTHKEY=$(vault read -field=key secret/tailscale)
   ansible-playbook playbook.yml --ask-become-pass \
     -e tailscale_authkey="$TAILSCALE_AUTHKEY"
   ```

### Sensitive Variables

Never commit sensitive data to git:

```yaml
# ❌ BAD - Don't do this
tailscale_authkey: "tskey-auth-actual-key-here"

# ✅ GOOD - Use environment variables or vault
tailscale_authkey: "{{ lookup('env', 'TAILSCALE_AUTHKEY') }}"

# ✅ GOOD - Use Ansible Vault
tailscale_authkey: "{{ vault_tailscale_authkey }}"
```

Create encrypted vault:
```bash
ansible-vault create secrets.yml
# Add: vault_tailscale_authkey: tskey-auth-xxxxx

ansible-playbook playbook.yml --ask-become-pass \
  -e @secrets.yml --ask-vault-pass
```

## Validation

After configuration, verify settings:

```bash
# Check what variables will be used
ansible-playbook playbook.yml --ask-become-pass \
  -e @vars.yml --check --diff

# View all variables
ansible-playbook playbook.yml --ask-become-pass \
  -e @vars.yml -e "ansible_check_mode=true" \
  --tags never -vv
```

## Troubleshooting

### SSH Keys Not Working

Check file ownership and permissions:
```bash
sudo ls -la /home/clawdbot/.ssh/
sudo cat /home/clawdbot/.ssh/authorized_keys
```

### Tailscale Not Connecting

Verify auth key is valid:
```bash
sudo tailscale up --authkey=YOUR_KEY --verbose
```

### Installation Mode Issues

Check which mode is active:
```bash
ansible-playbook playbook.yml --ask-become-pass \
  -e @vars.yml --check | grep "install_mode"
```

## See Also

- [Main README](../README.md)
- [Development Mode Guide](development-mode.md)
- [Upgrade Notes](../UPGRADE_NOTES.md)
- [Defaults File](../roles/clawdbot/defaults/main.yml)
