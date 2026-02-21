#!/bin/bash
set -e

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

# Run the Ansible playbook
if [ "$EUID" -eq 0 ]; then
    ansible-playbook playbook.yml -e ansible_become=false "$@"
    PLAYBOOK_EXIT=$?
else
    ansible-playbook playbook.yml --ask-become-pass "$@"
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
