#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_TMP=$(mktemp -d)
MOCK_BIN="$TEST_TMP/bin"
failures=0
checks=0

trap 'rm -rf "$TEST_TMP"' EXIT

pass() {
    checks=$((checks + 1))
    printf '[PASS] %s\n' "$1"
}

fail() {
    checks=$((checks + 1))
    failures=$((failures + 1))
    printf '[FAIL] %s\n' "$1" >&2
}

assert_status() {
    local name="$1"
    local expected="$2"
    local actual="$3"

    if [ "$expected" -eq "$actual" ]; then
        pass "$name"
    else
        fail "$name (expected status $expected, got $actual)"
    fi
}

assert_contains() {
    local name="$1"
    local value="$2"
    local expected="$3"

    if [[ "$value" == *"$expected"* ]]; then
        pass "$name"
    else
        fail "$name (missing: $expected)"
    fi
}

assert_not_contains() {
    local name="$1"
    local value="$2"
    local unexpected="$3"

    if [[ "$value" == *"$unexpected"* ]]; then
        fail "$name (unexpected: $unexpected)"
    else
        pass "$name"
    fi
}

reset_mocks() {
    rm -rf "$MOCK_BIN"
    mkdir -p "$MOCK_BIN"
}

make_success_mountpoint() {
    cat > "$MOCK_BIN/mountpoint" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/mountpoint"
}

make_fwconsole() {
    local status="$1"

    cat > "$MOCK_BIN/fwconsole" <<EOF
#!/bin/sh
cat <<'OUTPUT'
+------------+---------+----------+---------+
| Module     | Version | Status   | License |
+------------+---------+----------+---------+
| framework  | 17.0    | Enabled  | GPL     |
| testmodule | 1.0     | $status | GPL     |
+------------+---------+----------+---------+
OUTPUT
EOF
    chmod +x "$MOCK_BIN/fwconsole"
}

make_sudo_passthrough() {
    cat > "$MOCK_BIN/sudo" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-u" ]; then
    shift 2
fi
exec "$@"
EOF
    chmod +x "$MOCK_BIN/sudo"
}

make_system_mocks() {
    cat > "$MOCK_BIN/hostnamectl" <<'EOF'
#!/bin/sh
echo ' Static hostname: lab'
echo ' Operating System: Debian GNU/Linux 12'
echo ' Kernel: Linux 6.1'
echo ' Architecture: x86-64'
EOF

    cat > "$MOCK_BIN/lscpu" <<'EOF'
#!/bin/sh
echo 'Vendor ID: GenuineIntel'
echo 'Model name: Test CPU'
EOF

    cat > "$MOCK_BIN/free" <<'EOF'
#!/bin/sh
echo 'Mem: 1Gi 512Mi 512Mi'
EOF

    cat > "$MOCK_BIN/df" <<'EOF'
#!/bin/sh
case "$*" in
    *--total*)
        echo 'total 1024M 512M 512M 50% -'
        ;;
    *)
        echo 'Filesystem Size Used Avail Mounted on'
        echo '/dev/test 1G 512M 512M /'
        ;;
esac
EOF

    cat > "$MOCK_BIN/ip" <<'EOF'
#!/bin/sh
case "$*" in
    '-br -4 addr show')
        echo 'eth0 UP 192.0.2.10/24'
        ;;
    '-br -6 addr show')
        echo 'eth0 UP 2001:db8::10/64'
        ;;
    'route')
        echo 'default via 192.0.2.1 dev eth0'
        echo '192.0.2.0/24 dev eth0 proto kernel scope link src 192.0.2.10'
        ;;
    'route show default')
        echo 'default via 192.0.2.1 dev eth0'
        ;;
    'link show eth0'|'address show eth0'|'-s link show eth0')
        echo 'eth0: test interface'
        ;;
    *)
        exit 0
        ;;
esac
EOF

    cat > "$MOCK_BIN/wget" <<'EOF'
#!/bin/sh
echo '203.0.113.10'
EOF

    chmod +x "$MOCK_BIN/hostnamectl" "$MOCK_BIN/lscpu" "$MOCK_BIN/free" "$MOCK_BIN/df" "$MOCK_BIN/ip" "$MOCK_BIN/wget"
}

test_manual_backup_with_sh() {
    reset_mocks
    make_success_mountpoint

    local source_dir="$TEST_TMP/manual-source"
    local destination="$TEST_TMP/manual-destination"
    local log_file="$TEST_TMP/manual.log"
    local output status archive_count partial_count

    mkdir -p "$source_dir" "$destination"
    echo 'test' > "$source_dir/file.txt"

    output=$(printf '%s\n%s\n' "$source_dir" "$destination" | PATH="$MOCK_BIN:$PATH" LOG_FILE="$log_file" /bin/sh "$ROOT_DIR/backup/manual-backup.sh" 2>&1)
    status=$?

    assert_status "manual backup runs with /bin/sh" 0 "$status"
    assert_contains "manual backup prints final path" "$output" "Backup salvo em:"

    archive_count=$(find "$destination" -maxdepth 1 -type f -name 'backup-*.tar.gz' | wc -l)
    partial_count=$(find "$destination" -maxdepth 1 -type f -name '*.partial' | wc -l)
    assert_status "manual backup creates one final archive" 1 "$archive_count"
    assert_status "manual backup leaves no partial archive" 0 "$partial_count"
}

test_daily_backup_failure_cleanup() {
    reset_mocks
    make_success_mountpoint

    cat > "$MOCK_BIN/tar" <<'EOF'
#!/bin/sh
touch "$2"
exit 1
EOF
    chmod +x "$MOCK_BIN/tar"

    local source_dir="$TEST_TMP/daily-source"
    local destination="$TEST_TMP/daily-destination"
    local status archive_count partial_count

    mkdir -p "$source_dir" "$destination"

    PATH="$MOCK_BIN:$PATH" \
        BACKUP_PATH="$source_dir" \
        EXTERNAL_STORAGE="$destination" \
        LOG_FILE="$TEST_TMP/daily.log" \
        /bin/sh "$ROOT_DIR/backup/daily-backup.sh" >/dev/null 2>&1
    status=$?

    assert_status "daily backup returns failure when tar fails" 1 "$status"
    archive_count=$(find "$destination" -maxdepth 1 -type f -name 'backup-*.tar.gz' | wc -l)
    partial_count=$(find "$destination" -maxdepth 1 -type f -name '*.partial' | wc -l)
    assert_status "failed daily backup leaves no final archive" 0 "$archive_count"
    assert_status "failed daily backup removes partial archive" 0 "$partial_count"
}

test_network_exit_status() {
    reset_mocks

    cat > "$MOCK_BIN/ip" <<'EOF'
#!/bin/sh
case "$*" in
    'route show default') echo 'default via 192.0.2.1 dev eth0' ;;
    'link show eth0') exit 0 ;;
    *) exit 0 ;;
esac
EOF

    cat > "$MOCK_BIN/ethtool" <<'EOF'
#!/bin/sh
exit 0
EOF
    cat > "$MOCK_BIN/dig" <<'EOF'
#!/bin/sh
exit 0
EOF
    cat > "$MOCK_BIN/host" <<'EOF'
#!/bin/sh
exit 0
EOF
    cat > "$MOCK_BIN/ping" <<'EOF'
#!/bin/sh
case "$*" in
    *google.com*) exit 1 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$MOCK_BIN/ip" "$MOCK_BIN/ethtool" "$MOCK_BIN/dig" "$MOCK_BIN/host" "$MOCK_BIN/ping"

    local output status
    output=$(PATH="$MOCK_BIN:$PATH" LOG_FILE="$TEST_TMP/network.log" bash "$ROOT_DIR/network/check-network.sh" --full 2>&1)
    status=$?

    assert_status "network full check returns failure when one test fails" 1 "$status"
    assert_contains "network check reports failed name resolution ping" "$output" "Ping com resolução de nome OK"

    output=$(LOG_FILE="/this/path/is/not/used/by/help" bash "$ROOT_DIR/network/check-network.sh" --help 2>&1)
    status=$?
    assert_status "network help does not require log access" 0 "$status"
    assert_contains "network help uses the real script name" "$output" "check-network.sh"
}

test_zabbix_module_check() {
    reset_mocks
    make_sudo_passthrough
    make_fwconsole "Disabled"

    local output status
    output=$(PATH="$MOCK_BIN:$PATH" FWCONSOLE_BIN="$MOCK_BIN/fwconsole" LOG_FILE="$TEST_TMP/zabbix-modules.log" bash "$ROOT_DIR/monitoramento/check-modules-zabbix.sh" 2>&1)
    status=$?

    assert_status "Zabbix module check keeps text item exit status" 0 "$status"
    assert_contains "Zabbix module check detects Disabled" "$output" "PROBLEM"

    cat > "$MOCK_BIN/sudo" <<'EOF'
#!/bin/sh
exit 1
EOF
    chmod +x "$MOCK_BIN/sudo"

    output=$(PATH="$MOCK_BIN:$PATH" FWCONSOLE_BIN="$MOCK_BIN/fwconsole" LOG_FILE="$TEST_TMP/zabbix-modules-fail.log" bash "$ROOT_DIR/monitoramento/check-modules-zabbix.sh" 2>&1)
    assert_contains "Zabbix module check does not report OK when fwconsole fails" "$output" "PROBLEM"
}

test_freepbx_module_check() {
    reset_mocks
    make_fwconsole "Disabled"

    local output status
    output=$(PATH="$MOCK_BIN:$PATH" FWCONSOLE_BIN="$MOCK_BIN/fwconsole" LOG_FILE="$TEST_TMP/freepbx.log" NO_BANNER=1 bash "$ROOT_DIR/voip/check-freepbx-modules.sh" 2>&1)
    status=$?
    assert_status "FreePBX module check fails on Disabled" 1 "$status"
    assert_contains "FreePBX module check names disabled module" "$output" "testmodule"

    make_fwconsole "Enabled"
    output=$(PATH="$MOCK_BIN:$PATH" FWCONSOLE_BIN="$MOCK_BIN/fwconsole" LOG_FILE="$TEST_TMP/freepbx-ok.log" NO_BANNER=1 bash "$ROOT_DIR/voip/check-freepbx-modules.sh" 2>&1)
    status=$?
    assert_status "FreePBX module check passes when modules are enabled" 0 "$status"
    assert_contains "FreePBX module check prints healthy result" "$output" "nenhum módulo desabilitado"
}

test_zabbix_discovery() {
    reset_mocks

    cat > "$MOCK_BIN/asterisk" <<'EOF'
#!/bin/sh
cat <<'OUTPUT'
Name/username             Host                                    Dyn Forcerport Comedia    ACL Port     Status      Description
1001/1001                 192.0.2.50                               D  Yes        Yes            5060     OK (12 ms)
1 sip peers [Monitored: 1 online, 0 offline Unmonitored: 0 online, 0 offline]
OUTPUT
EOF
    chmod +x "$MOCK_BIN/asterisk"

    local output status
    output=$(PATH="$MOCK_BIN:$PATH" bash "$ROOT_DIR/monitoramento/zabbix-extensions-discovery.sh" 2>&1)
    status=$?

    assert_status "Zabbix discovery succeeds with Asterisk output" 0 "$status"
    assert_contains "Zabbix discovery strips SIP username suffix" "$output" '"{#EXTEN}":"1001"'
    assert_contains "Zabbix discovery keeps peer IP" "$output" '"{#IP}":"192.0.2.50"'
    assert_contains "Zabbix discovery does not invent a device" "$output" '"{#DEVICE}":"UNKNOWN"'

    cat > "$MOCK_BIN/asterisk" <<'EOF'
#!/bin/sh
exit 1
EOF
    chmod +x "$MOCK_BIN/asterisk"

    PATH="$MOCK_BIN:$PATH" bash "$ROOT_DIR/monitoramento/zabbix-extensions-discovery.sh" >/dev/null 2>&1
    status=$?
    assert_status "Zabbix discovery fails when Asterisk query fails" 1 "$status"
}

test_extension_count() {
    reset_mocks

    cat > "$MOCK_BIN/asterisk" <<'EOF'
#!/bin/sh
echo '/other/key : value'
EOF
    chmod +x "$MOCK_BIN/asterisk"

    local output status
    output=$(PATH="$MOCK_BIN:$PATH" bash "$ROOT_DIR/voip/check-extensions.sh" 2>&1)
    status=$?
    assert_status "extension check succeeds with no registrations" 0 "$status"
    assert_contains "extension check reports zero instead of one empty extension" "$output" "Total de Ramais: 0"

    cat > "$MOCK_BIN/asterisk" <<'EOF'
#!/bin/sh
echo '/registrar/contact/1001 : {"via_addr":"192.0.2.60:5060","endpoint":"1001","user_agent":"Desk Phone"}'
EOF
    chmod +x "$MOCK_BIN/asterisk"

    output=$(PATH="$MOCK_BIN:$PATH" bash "$ROOT_DIR/voip/check-extensions.sh" 2>&1)
    assert_contains "extension check parses endpoint" "$output" "Ramal: 1001"
    assert_contains "extension check parses registration address" "$output" "192.0.2.60:5060"
    assert_contains "extension check parses user agent" "$output" "Desk Phone"
    assert_contains "extension check counts one real extension" "$output" "Total de Ramais: 1"
}

test_linux_route_report() {
    reset_mocks
    make_system_mocks

    local config_dir="$TEST_TMP/asterisk-conf"
    local output status
    mkdir -p "$config_dir"
    printf 'externip=203.0.113.20\nlocalnet=192.0.2.0/24\n' > "$config_dir/sip.conf"

    output=$(PATH="$MOCK_BIN:$PATH" ASTERISK_CONF_DIR="$config_dir" NO_BANNER=1 bash "$ROOT_DIR/voip/check-linux-asterisk.sh" 2>&1)
    status=$?

    assert_status "Linux/Asterisk report runs with controlled fixtures" 0 "$status"
    assert_contains "connected route has no invented gateway" "$output" "Destino: 192.0.2.0/24 | Via: - | Interface: eth0"
    assert_contains "default route keeps gateway and interface" "$output" "Destino: default | Via: 192.0.2.1 | Interface: eth0"
}

test_queue_exact_match() {
    reset_mocks

    cat > "$MOCK_BIN/asterisk" <<'EOF'
#!/bin/sh
case "${2:-}" in
    'queue show')
        cat <<'OUTPUT'
12 has 0 calls (max unlimited) in 'ringall' strategy (0s holdtime, 0s talktime), W:0, C:0, A:0, SL:0.0%, SL2:0.0% within 60s
   Members:
      Local/1001@from-queue/n (ringinuse disabled) (Not in use) has taken no calls yet

123 has 0 calls (max unlimited) in 'leastrecent' strategy (0s holdtime, 0s talktime), W:0, C:0, A:0, SL:0.0%, SL2:0.0% within 60s
   Members:
      Local/1002@from-queue/n (ringinuse disabled) (Not in use) has taken no calls yet
OUTPUT
        ;;
    'queue show 12')
        cat <<'OUTPUT'
12 has 0 calls (max unlimited) in 'ringall' strategy (0s holdtime, 0s talktime), W:0, C:0, A:0, SL:0.0%, SL2:0.0% within 60s
   Members:
      Local/1001@from-queue/n (ringinuse disabled) (Not in use) has taken no calls yet
OUTPUT
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$MOCK_BIN/asterisk"

    local output status
    output=$(printf '1\n12\n' | PATH="$MOCK_BIN:$PATH" ASTERISK_BIN="$MOCK_BIN/asterisk" bash "$ROOT_DIR/voip/check-queues.sh" 2>&1)
    status=$?

    assert_status "queue check accepts an exact queue" 0 "$status"
    assert_contains "queue check shows selected member" "$output" "1001"
    assert_not_contains "queue check does not match queue 123 by substring" "$output" "1002"

    output=$(printf '1\n1\n' | PATH="$MOCK_BIN:$PATH" ASTERISK_BIN="$MOCK_BIN/asterisk" bash "$ROOT_DIR/voip/check-queues.sh" 2>&1)
    status=$?
    assert_status "queue check rejects a non-existent partial queue name" 1 "$status"
}

test_voip_aggregator() {
    reset_mocks
    make_system_mocks
    make_fwconsole "Enabled"

    local config_dir="$TEST_TMP/aggregate-asterisk-conf"
    local output status
    mkdir -p "$config_dir"
    printf 'externip=203.0.113.30\nlocalnet=192.0.2.0/24\n' > "$config_dir/sip.conf"

    output=$(PATH="$MOCK_BIN:$PATH" ASTERISK_CONF_DIR="$config_dir" FWCONSOLE_BIN="$MOCK_BIN/fwconsole" LOG_FILE="$TEST_TMP/aggregate.log" bash "$ROOT_DIR/voip/check-voip.sh" 2>&1)
    status=$?

    assert_status "VoIP aggregate check propagates successful child checks" 0 "$status"
    assert_contains "VoIP aggregate check runs FreePBX module section" "$output" "VERIFICAÇÃO DOS MÓDULOS DO FREEPBX"
}

main() {
    test_manual_backup_with_sh
    test_daily_backup_failure_cleanup
    test_network_exit_status
    test_zabbix_module_check
    test_freepbx_module_check
    test_zabbix_discovery
    test_extension_count
    test_linux_route_report
    test_queue_exact_match
    test_voip_aggregator

    echo
    printf '%d checks, %d failure(s)\n' "$checks" "$failures"
    [ "$failures" -eq 0 ]
}

main "$@"
