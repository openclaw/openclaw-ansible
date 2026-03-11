#!/bin/bash
set -e

# Run OpenClaw playbook from local source or installed collection

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"

# Keep instructions aligned when user overrides openclaw_user via -e.
extract_openclaw_user_from_args() {
    local prev_is_extra=0
    local arg
    for arg in "$@"; do
        if [ "$prev_is_extra" -eq 1 ]; then
            if [[ "$arg" =~ (^|[[:space:]])openclaw_user=([^[:space:]]+) ]]; then
                OPENCLAW_USER="${BASH_REMATCH[2]}"
            fi
            prev_is_extra=0
            continue
        fi

        case "$arg" in
            -e|--extra-vars)
                prev_is_extra=1
                ;;
            -e=*|--extra-vars=*)
                local extra="${arg#*=}"
                if [[ "$extra" =~ (^|[[:space:]])openclaw_user=([^[:space:]]+) ]]; then
                    OPENCLAW_USER="${BASH_REMATCH[2]}"
                fi
                ;;
        esac
    done
}

extract_openclaw_user_from_args "$@"

# Determine playbook source
if [ -f "playbooks/install.yml" ]; then
    echo "Running from local source..."
    PLAYBOOK="playbook.yml"
    export ANSIBLE_ROLES_PATH="${PWD}/roles:${ANSIBLE_ROLES_PATH}"
elif ansible-galaxy collection list 2>/dev/null | grep -q "openclaw.installer"; then
    echo "Running from installed collection..."
    PLAYBOOK="openclaw.installer.install"
else
    echo "Error: Collection not installed and not running from source"
    echo "Install with: ansible-galaxy collection install -r requirements.yml"
    exit 1
fi

# Run the Ansible playbook
if [ "$EUID" -eq 0 ]; then
    ansible-playbook "$PLAYBOOK" -e ansible_become=false "$@"
    PLAYBOOK_EXIT=$?
else
    ansible-playbook "$PLAYBOOK" --ask-become-pass "$@"
    PLAYBOOK_EXIT=$?
fi

# After playbook completes successfully, show instructions
if [ $PLAYBOOK_EXIT -eq 0 ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "✅ INSTALLATION COMPLETE!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "🔄 SWITCH TO OPENCLAW USER with:"
    echo ""
    echo "    sudo su - ${OPENCLAW_USER}"
    echo ""
    echo "  OR (alternative):"
    echo ""
    echo "    sudo -u ${OPENCLAW_USER} -i"
    echo ""
    echo "This will switch you to the OpenClaw user with a proper"
    echo "login shell (loads .bashrc, sets environment correctly)."
    echo ""
    echo "After switching, you'll see the next setup steps:"
    echo "  • Configure OpenClaw (~/.openclaw/config.yml)"
    echo "  • Login to messaging provider (WhatsApp/Telegram/Signal)"
    echo "  • Test the gateway"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""
else
    echo "❌ Playbook failed with exit code $PLAYBOOK_EXIT"
    exit $PLAYBOOK_EXIT
fi
