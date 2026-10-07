#!/usr/bin/env bash
set -euo pipefail

# Network namespaces keep the host's routes and firewall untouched.
if [ "$EUID" -ne 0 ] || [ "$(uname -s)" != Linux ]; then
    echo 'Run as root on a disposable Linux host with Ansible and iproute2.' >&2
    exit 1
fi
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
namespace="openclaw-route-$$"
external="openclaw-external-$$"
container="openclaw-container-$$"
cleanup() {
    if [ -n "${server_pid:-}" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    ip netns delete "$namespace" 2>/dev/null || true
    ip netns delete "$external" 2>/dev/null || true
    ip netns delete "$container" 2>/dev/null || true
    rm -rf "$work"
}
trap cleanup EXIT

# Execute the production parser, assertions, sysfs lookup, and rule renderer.
# Only the destination file changes; never write the host's UFW configuration.
python3 - "$root" "$work" <<'PY'
import pathlib
import sys
import yaml
root, work = map(pathlib.Path, sys.argv[1:])
tasks = yaml.safe_load((root / 'roles/openclaw/tasks/firewall-linux.yml').read_text())
start = next(i for i, task in enumerate(tasks) if task['name'] == 'Get default network interface')
end = next(i for i, task in enumerate(tasks) if task['name'] == 'Create UFW after.rules for Docker isolation')
selected = tasks[start:end + 1]
selected[-1]['ansible.builtin.blockinfile']['path'] = str(work / 'after.rules')
selected.append({'name': 'Check the selected interface', 'ansible.builtin.assert': {
    'that': 'default_interface.stdout == expected_interface'}})
(work / 'check.yml').write_text(yaml.safe_dump([{
    'name': 'Verify production default-route handling', 'hosts': 'localhost',
    'connection': 'local', 'gather_facts': False, 'tasks': selected,
}]))
PY

ip netns add "$namespace"
ip -n "$namespace" link set lo up
for device in eth0 ppp0 _wan0 eth1 eth2; do
    ip -n "$namespace" link add "$device" type dummy
    ip -n "$namespace" link set "$device" up
done
ip -n "$namespace" address add 192.0.2.2/24 dev eth0
ip -n "$namespace" address add 198.51.100.2/24 dev eth1
ip -n "$namespace" address add 203.0.113.2/24 dev eth2

check_route() {
    local expected=$1
    shift
    ip -n "$namespace" route flush default
    ip -n "$namespace" route add default "$@"
    printf '*filter\nCOMMIT\n' > "$work/after.rules"
    ip netns exec "$namespace" ansible-playbook "$work/check.yml" -e "expected_interface=$expected"
    grep -Fx -- "-A DOCKER-USER -i $expected -j DROP" "$work/after.rules"
    ip netns exec "$namespace" ansible-playbook "$work/check.yml" -e "expected_interface=$expected" > "$work/reapply.log"
    cat "$work/reapply.log"
    grep -Eq 'changed=0 .*failed=0' "$work/reapply.log"
}

check_route eth0 via 192.0.2.1 dev eth0
check_route ppp0 dev ppp0
check_route _wan0 dev _wan0
check_route eth1 nexthop via 198.51.100.1 dev eth1 weight 1 nexthop via 203.0.113.1 dev eth2 weight 1

# Exercise the generated DOCKER-USER rules with real forwarded HTTP traffic.
# Separate namespaces model an external client, host, and container network.
ip -n "$namespace" route flush default
ip -n "$namespace" link delete _wan0
ip netns add "$external"
ip netns add "$container"
ip -n "$namespace" link add _wan0 type veth peer name client
ip -n "$namespace" link set client netns "$external"
ip -n "$namespace" address add 192.0.2.1/24 dev _wan0
ip -n "$namespace" address flush dev eth0
ip -n "$namespace" link set _wan0 up
ip -n "$external" address add 192.0.2.2/24 dev client
ip -n "$external" link set client up
ip -n "$external" link set lo up
ip -n "$external" route add default via 192.0.2.1
ip -n "$namespace" link add bridge0 type veth peer name app
ip -n "$namespace" link set app netns "$container"
ip -n "$namespace" address add 10.23.0.1/24 dev bridge0
ip -n "$namespace" link set bridge0 up
ip -n "$container" address add 10.23.0.2/24 dev app
ip -n "$container" link set app up
ip -n "$container" link set lo up
ip -n "$container" route add default via 10.23.0.1
ip netns exec "$namespace" sysctl -qw net.ipv4.ip_forward=1
ip netns exec "$container" python3 -m http.server 38081 --bind 10.23.0.2 --directory "$work" > "$work/http.log" 2>&1 &
server_pid=$!
ip netns exec "$external" curl --noproxy '*' --retry 10 --retry-connrefused --retry-delay 1 -fsS http://10.23.0.2:38081/check.yml > /dev/null
check_route _wan0 via 192.0.2.2 dev _wan0
ip netns exec "$namespace" iptables-restore < "$work/after.rules"
ip netns exec "$namespace" iptables -A FORWARD -j DOCKER-USER
if ip netns exec "$external" curl --noproxy '*' --max-time 2 -fsS http://10.23.0.2:38081/check.yml > /dev/null 2>&1; then
    echo 'External forwarded HTTP bypassed isolation.' >&2
    exit 1
fi
ip netns exec "$namespace" curl --noproxy '*' -fsS http://10.23.0.2:38081/check.yml > /dev/null
ip netns exec "$namespace" iptables -L DOCKER-USER -n -v
echo 'External HTTP blocked; host-local HTTP succeeds.'

ip -n "$namespace" route flush default
printf '*filter\nCOMMIT\n' > "$work/after.rules"
if ip netns exec "$namespace" ansible-playbook "$work/check.yml" -e expected_interface=missing > "$work/no-route.log" 2>&1; then
    echo 'Missing default route unexpectedly accepted.' >&2
    exit 1
fi
grep -F 'Failed to detect default network interface' "$work/no-route.log"
if grep -q DOCKER-USER "$work/after.rules"; then
    echo 'Missing default route installed an isolation rule.' >&2
    exit 1
fi
echo 'Production default-route detection, validation, and rule reapplication: PASSED'
