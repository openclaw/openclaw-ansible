# Development Mode Installation

This guide explains how to install Clawdbot in **development mode**, where the application is built from source instead of installed from npm.

## Overview

### Release Mode vs Development Mode

| Feature | Release Mode | Development Mode |
|---------|-------------|------------------|
| Source | npm registry | GitHub repository |
| Installation | `pnpm install -g clawdbot@latest` | `git clone` + `pnpm build` |
| Location | `~/.local/share/pnpm/global/...` | `~/code/clawdbot/` |
| Binary | Global pnpm package | Symlink to `bin/clawdbot.js` |
| Updates | `pnpm install -g clawdbot@latest` | `git pull` + `pnpm build` |
| Use Case | Production, stable deployments | Development, testing, debugging |
| Recommended For | End users | Developers, contributors |

## Installation

### Quick Install

```bash
# Clone the ansible installer
git clone https://github.com/openclaw/openclaw-ansible.git
cd openclaw-ansible

# Run in development mode
./run-playbook.sh -e clawdbot_install_mode=development
```

### Manual Install

```bash
# Install ansible
sudo apt update && sudo apt install -y ansible git

# Clone repository
git clone https://github.com/openclaw/openclaw-ansible.git
cd openclaw-ansible

# Install collections
ansible-galaxy collection install -r requirements.yml

# Run playbook with development mode
ansible-playbook playbook.yml --ask-become-pass -e clawdbot_install_mode=development
```

## What Gets Installed

### Directory Structure

```
/home/clawdbot/
├── .clawdbot/              # Configuration directory
│   ├── sessions/
│   ├── credentials/
│   ├── data/
│   └── logs/
├── .local/
│   ├── bin/
│   │   └── clawdbot       # Symlink -> ~/code/clawdbot/bin/clawdbot.js
│   └── share/pnpm/
└── code/
    └── clawdbot/          # Git repository
        ├── bin/
        │   └── clawdbot.js
        ├── dist/          # Built files
        ├── src/           # Source code
        ├── package.json
        └── pnpm-lock.yaml
```

### Installation Steps

The Ansible playbook performs these steps:

1. **Create `~/code` directory**
   ```bash
   mkdir -p ~/code
   ```

2. **Clone repository**
   ```bash
   cd ~/code
   git clone https://github.com/clawdbot/clawdbot.git
   ```

3. **Install dependencies**
   ```bash
   cd clawdbot
   pnpm install
   ```

4. **Build from source**
   ```bash
   pnpm build
   ```

5. **Create symlink**
   ```bash
   ln -sf ~/code/clawdbot/bin/clawdbot.js ~/.local/bin/clawdbot
   chmod +x ~/code/clawdbot/bin/clawdbot.js
   ```

6. **Add development aliases** to `.bashrc`:
   ```bash
   alias clawdbot-rebuild='cd ~/code/clawdbot && pnpm build'
   alias clawdbot-dev='cd ~/code/clawdbot'
   alias clawdbot-pull='cd ~/code/clawdbot && git pull && pnpm install && pnpm build'
   ```

## Development Workflow

### Making Changes

```bash
# 1. Navigate to repository
clawdbot-dev
# or: cd ~/code/clawdbot

# 2. Make your changes
vim src/some-file.ts

# 3. Rebuild
clawdbot-rebuild
# or: pnpm build

# 4. Test immediately
clawdbot --version
clawdbot doctor
```

### Pulling Updates

```bash
# Pull latest changes and rebuild
clawdbot-pull

# Or manually:
cd ~/code/clawdbot
git pull
pnpm install
pnpm build
```

### Testing Changes

```bash
# After rebuilding, the clawdbot command uses the new code immediately
clawdbot status
clawdbot gateway

# View daemon logs
clawdbot logs
```

### Switching Branches

```bash
cd ~/code/clawdbot

# Switch to feature branch
git checkout feature-branch
pnpm install
pnpm build

# Switch back to main
git checkout main
pnpm install
pnpm build
```

## Development Aliases

The following aliases are added to `.bashrc`:

| Alias | Command | Purpose |
|-------|---------|---------|
| `clawdbot-dev` | `cd ~/code/clawdbot` | Navigate to repo |
| `clawdbot-rebuild` | `cd ~/code/clawdbot && pnpm build` | Rebuild after changes |
| `clawdbot-pull` | `cd ~/code/clawdbot && git pull && pnpm install && pnpm build` | Update and rebuild |

Plus an environment variable:

```bash
export CLAWDBOT_DEV_DIR="$HOME/code/clawdbot"
```

## Configuration Variables

You can customize the development installation:

```yaml
# In playbook or command line
clawdbot_install_mode: "development"
clawdbot_repo_url: "https://github.com/clawdbot/clawdbot.git"
clawdbot_repo_branch: "main"
clawdbot_code_dir: "/home/clawdbot/code"
clawdbot_repo_dir: "/home/clawdbot/code/clawdbot"
```

### Using a Fork

```bash
ansible-playbook playbook.yml --ask-become-pass \
  -e clawdbot_install_mode=development \
  -e clawdbot_repo_url=https://github.com/YOUR_USERNAME/clawdbot.git \
  -e clawdbot_repo_branch=your-feature-branch
```

### Custom Location

```bash
ansible-playbook playbook.yml --ask-become-pass \
  -e clawdbot_install_mode=development \
  -e clawdbot_code_dir=/home/clawdbot/projects
```

## Switching Between Modes

### From Release to Development

```bash
# Uninstall global package
pnpm uninstall -g clawdbot

# Run ansible in development mode
ansible-playbook playbook.yml --ask-become-pass -e clawdbot_install_mode=development
```

### From Development to Release

```bash
# Remove symlink
rm ~/.local/bin/clawdbot

# Remove repository (optional)
rm -rf ~/code/clawdbot

# Install from npm
pnpm install -g clawdbot@latest
```

## Troubleshooting

### Build Fails

```bash
cd ~/code/clawdbot

# Check Node.js version (needs 22.x)
node --version

# Clean install
rm -rf node_modules
pnpm install
pnpm build
```

### Symlink Not Working

```bash
# Check symlink
ls -la ~/.local/bin/clawdbot

# Recreate symlink
rm ~/.local/bin/clawdbot
ln -sf ~/code/clawdbot/bin/clawdbot.js ~/.local/bin/clawdbot
chmod +x ~/code/clawdbot/bin/clawdbot.js
```

### Command Not Found

```bash
# Ensure ~/.local/bin is in PATH
echo $PATH | grep -q ".local/bin" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Git Issues

```bash
cd ~/code/clawdbot

# Reset to clean state
git reset --hard origin/main
git clean -fdx

# Rebuild
pnpm install
pnpm build
```

## Performance Considerations

### Build Time

First build takes longer (~1-2 minutes depending on system):
```bash
pnpm install    # Downloads dependencies
pnpm build      # Compiles TypeScript
```

Subsequent rebuilds are faster (~10-30 seconds):
```bash
pnpm build      # Only recompiles changed files
```

### Disk Usage

Development mode uses more disk space:

- **Release mode**: ~150 MB (global pnpm cache)
- **Development mode**: ~400 MB (repo + node_modules + dist)

### Memory Usage

No difference in runtime memory usage between modes.

## CI/CD Integration

### Testing Before Merge

```bash
# Test specific commit
cd ~/code/clawdbot
git fetch origin pull/123/head:pr-123
git checkout pr-123
pnpm install
pnpm build

# Test it
clawdbot doctor
```

### Automated Testing

```bash
#!/bin/bash
# test-clawdbot.sh

cd ~/code/clawdbot
git pull
pnpm install
pnpm build

# Run tests
pnpm test

# Integration test
clawdbot doctor
```

## Best Practices

### Development Workflow

1. ✅ **Always rebuild after code changes**
   ```bash
   clawdbot-rebuild
   ```

2. ✅ **Test changes before committing**
   ```bash
   pnpm build && clawdbot doctor
   ```

3. ✅ **Keep dependencies updated**
   ```bash
   pnpm update
   pnpm build
   ```

4. ✅ **Use feature branches**
   ```bash
   git checkout -b feature/my-feature
   ```

### Don't Do

- ❌ Editing code without rebuilding
- ❌ Running `pnpm link` manually (breaks setup)
- ❌ Installing global packages while in dev mode
- ❌ Modifying symlink manually

## Advanced Usage

### Multiple Repositories

You can have multiple clones:

```bash
# Main development
~/code/clawdbot/          # main branch

# Experimental features
~/code/clawdbot-test/     # testing branch

# Switch binary symlink
ln -sf ~/code/clawdbot-test/bin/clawdbot.js ~/.local/bin/clawdbot
```

### Custom Build Options

```bash
cd ~/code/clawdbot

# Development build (faster, includes source maps)
NODE_ENV=development pnpm build

# Production build (optimized)
NODE_ENV=production pnpm build
```

### Debugging

```bash
# Run with debug output
DEBUG=* clawdbot gateway

# Or specific namespaces
DEBUG=clawdbot:* clawdbot gateway
```

## See Also

- [Main README](../README.md)
- [Security Architecture](security.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Clawdbot Repository](https://github.com/clawdbot/clawdbot)
