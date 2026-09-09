#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_TMP=$(mktemp -d)
MOCK_BIN="$TEST_TMP/bin"
checks=0
failures=0

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
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" -eq "$actual" ]; then
        pass "$name"
    else
        fail "$name (expected $expected, got $actual)"
    fi
}

assert_contains() {
    local name="$1" value="$2" expected="$3"
    if [[ "$value" == *"$expected"* ]]; then
        pass "$name"
    else
        fail "$name (missing: $expected)"
    fi
}

reset_mocks() {
    rm -rf "$MOCK_BIN"
    mkdir -p "$MOCK_BIN"
}

test_backup_members_are_relative() {
    reset_mocks

    cat > "$MOCK_BIN/mountpoint" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/mountpoint"

    local source_dir="$TEST_TMP/relative-source"
    local destination="$TEST_TMP/relative-destination"
    local archive first_member status

    mkdir -p "$source_dir" "$destination"
    echo 'data' > "$source_dir/file.txt"

    PATH="$MOCK_BIN:$PATH" \
        BACKUP_PATH="$source_dir" \
        EXTERNAL_STORAGE="$destination" \
        LOG_FILE="$TEST_TMP/relative.log" \
        /bin/sh "$ROOT_DIR/backup/daily-backup.sh" >/dev/null 2>&1
    status=$?
    assert_status "daily backup succeeds with controlled mountpoint" 0 "$status"

    archive=$(find "$destination" -maxdepth 1 -type f -name 'backup-*.tar.gz' | head -n 1)
    first_member=$(tar -tzf "$archive" | head -n 1)

    case "$first_member" in
        /*) fail "backup archive does not store absolute member paths" ;;
        *) pass "backup archive does not store absolute member paths" ;;
    esac
}

test_empty_fwconsole_is_not_healthy() {
    reset_mocks

    cat > "$MOCK_BIN/fwconsole" <<'EOF'
#!/bin/sh
exit 0
EOF
    cat > "$MOCK_BIN/sudo" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-u" ]; then
    shift 2
fi
exec "$@"
EOF
    chmod +x "$MOCK_BIN/fwconsole" "$MOCK_BIN/sudo"

    local output status

    output=$(PATH="$MOCK_BIN:$PATH" FWCONSOLE_BIN="$MOCK_BIN/fwconsole" LOG_FILE="$TEST_TMP/zabbix-empty.log" bash "$ROOT_DIR/monitoramento/check-modules-zabbix.sh" 2>&1)
    status=$?
    assert_status "Zabbix text check keeps status 0 for a PROBLEM value" 0 "$status"
    assert_contains "empty fwconsole output becomes PROBLEM in Zabbix" "$output" "PROBLEM"

    PATH="$MOCK_BIN:$PATH" FWCONSOLE_BIN="$MOCK_BIN/fwconsole" LOG_FILE="$TEST_TMP/freepbx-empty.log" NO_BANNER=1 bash "$ROOT_DIR/voip/check-freepbx-modules.sh" >/dev/null 2>&1
    status=$?
    assert_status "standalone FreePBX check fails on empty fwconsole output" 1 "$status"
}

test_queue_disappearing_between_queries() {
    reset_mocks

    cat > "$MOCK_BIN/asterisk" <<'EOF'
#!/bin/sh
case "${2:-}" in
    'queue show')
        echo "12 has 0 calls (max unlimited) in 'ringall' strategy"
        ;;
    'queue show 12')
        echo 'No such queue: 12.'
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

    assert_status "queue check fails if selected queue disappears" 1 "$status"
    assert_contains "queue check explains disappearing queue" "$output" "Fila não encontrada durante a consulta"
}

main() {
    test_backup_members_are_relative
    test_empty_fwconsole_is_not_healthy
    test_queue_disappearing_between_queries

    echo
    printf '%d checks, %d failure(s)\n' "$checks" "$failures"
    [ "$failures" -eq 0 ]
}

main "$@"
