# infra-scripts

Small scripts I use for infrastructure work.

Most of this repository came from the same situation: I had to check something more than once, got tired of doing it by hand, and turned it into a script.

Nothing fancy. Just useful stuff for Linux, networks, monitoring, backups and VoIP.

— **Murilo Prestes**

## Repository layout

```text
.
├── backup/
├── monitoramento/
├── network/
├── voip/
├── tests/
└── verify.sh
```

I keep the folders shallow on purpose. These are small operational tools, not a framework.

## Backup

### `backup/daily-backup.sh`

Creates a timestamped `.tar.gz` backup from a configured directory to a mounted destination.

The defaults are only placeholders. I normally set the paths with environment variables:

```bash
BACKUP_PATH=/srv/data \
EXTERNAL_STORAGE=/mnt/backup \
LOG_FILE=/var/log/daily-backup.log \
./backup/daily-backup.sh
```

The script refuses to continue if the source directory does not exist or the destination is not a mount point.

It writes to a `.partial` file first and only renames it after `tar` succeeds. Archive members are stored without absolute paths so a later restore is not tied to the original root filesystem path.

### `backup/manual-backup.sh`

Same basic backup flow, but asks for the source and destination interactively.

```bash
./backup/manual-backup.sh
```

This one intentionally uses POSIX `sh`, so it also works on systems where `/bin/sh` is `dash`.

## Network

### `network/check-network.sh`

A small network troubleshooting helper.

Help:

```bash
./network/check-network.sh --help
```

Full check:

```bash
sudo ./network/check-network.sh --full
```

Specific interface:

```bash
sudo ./network/check-network.sh --full --interface=eth0
```

DNS only:

```bash
sudo ./network/check-network.sh --dns-only
```

It checks things such as:

- interface addresses
- routes
- interface statistics
- `ethtool`
- configured resolvers
- DNS lookups
- ping by IP and hostname
- one IPv4 DF test with a 1472-byte payload

The DF test is evidence only. A failed 1472-byte ping does **not** automatically mean the interface MTU is wrong.

The full and DNS-only modes return a non-zero status if one of their checks fails.

By default the log goes to `/var/log/net-troubleshoot.log`. For tests or non-root use I can change it:

```bash
LOG_FILE=/tmp/net-check.log ./network/check-network.sh --dns-only
```

## Monitoring

### `monitoramento/check-modules-zabbix.sh`

Checks the FreePBX module list and prints one value for a Zabbix text item:

```text
OK
```

or:

```text
PROBLEM
```

It treats a disabled module, a failed `fwconsole` call or an unrecognizable empty module list as `PROBLEM`.

The script intentionally keeps exit status `0` when the result is `PROBLEM`; the monitoring value is the text printed to stdout. This avoids turning an expected problem state into an unsupported Zabbix item.

The FreePBX path and log path can be overridden for a different installation:

```bash
FWCONSOLE_BIN=/var/lib/asterisk/bin/fwconsole \
LOG_FILE=/tmp/modules.log \
./monitoramento/check-modules-zabbix.sh
```

### `monitoramento/zabbix-extensions-discovery.sh`

Builds classic Zabbix low-level discovery JSON from `asterisk -rx "sip show peers"`.

The discovery exposes:

```text
{#EXTEN}
{#IP}
{#DEVICE}
```

`{#DEVICE}` currently returns `UNKNOWN`. `sip show peers` does not contain the phone User-Agent, and I prefer an explicit unknown value over pretending another column is the device model.

If the Asterisk command itself fails, the script returns an error instead of returning an empty discovery list. An empty list could otherwise look like “there are no peers” when the real problem is that the query failed.

## VoIP

### `voip/check-extensions.sh`

Reads Asterisk database entries that contain registration information and prints:

- endpoint
- registration address
- User-Agent
- total parsed registrations

If there are no matching registrations, the total is `0` instead of producing one empty entry.

### `voip/check-freepbx-modules.sh`

Human-readable version of the FreePBX module check.

```bash
./voip/check-freepbx-modules.sh
```

It returns non-zero when:

- `fwconsole ma list` fails;
- the module list cannot be recognized;
- at least one module is disabled.

### `voip/check-linux-asterisk.sh`

Collects a read-only Linux/Asterisk snapshot with:

- hostname, OS and kernel
- uptime
- CPU and memory
- filesystem usage
- IPv4 and IPv6 addresses
- routes
- DNS configuration
- Asterisk `externip`
- Asterisk `localnet`
- current public IP lookup

Routes are parsed by the `via` and `dev` fields instead of fixed column numbers. That matters for directly connected routes, which do not have a `via` field.

The public IP lookup uses `https://ipinfo.io/ip` with a short timeout. The rest of the report is local.

### `voip/check-queues.sh`

Interactive queue inspection using `asterisk -rx "queue show"`.

It can show one queue or all queues and prints the queue strategy plus `Local/` members.

Queue names are matched exactly. Asking for queue `12` does not accidentally select queue `123`.

### `voip/check-voip.sh`

A small combined report.

Instead of carrying another copy of the Linux and FreePBX logic, it calls:

```text
check-linux-asterisk.sh
        +
check-freepbx-modules.sh
```

That keeps one implementation of each check and makes the combined script easier to follow.

## Main dependencies

Depending on the script, the repository uses standard Linux tools plus:

```text
bash
sh
tar
mountpoint
ip
ping
ethtool
dig
host
wget
awk
sed
grep
asterisk
fwconsole
sudo
```

Not every script needs every command. The VoIP/FreePBX scripts obviously only make sense on hosts where those tools exist.

## Verify the repository

Basic file and syntax checks:

```bash
bash verify.sh
```

Regression tests:

```bash
bash tests/run-tests.sh
bash tests/review-regressions.sh
```

The test suite uses temporary directories and mocked system commands. It does not connect to a real Asterisk, FreePBX server, customer network or production environment.

Pull requests also run ShellCheck in GitHub Actions.

## What the tests currently cover

The regression suite includes cases for:

- manual backup under `/bin/sh`
- cleanup after a failed backup
- relative archive paths
- network failure exit codes
- disabled and empty FreePBX module output
- failed Asterisk discovery
- zero versus one parsed registration
- directly connected versus gateway routes
- exact queue matching
- a queue disappearing between two queries
- the combined VoIP check

## Safety notes

These scripts are mostly read-only checks, with a few exceptions:

- backup scripts create archives and log files;
- network checks create/append their log file;
- module checks may append logs under `/var/log`;
- DNS, ping and public-IP checks create normal outbound diagnostic traffic.

They do not change Asterisk configuration, FreePBX modules, interfaces, routes or firewall rules.

I still read the output before making changes to a server. A script collecting evidence is not a replacement for understanding the problem.

## License

MIT. See `LICENSE`.
