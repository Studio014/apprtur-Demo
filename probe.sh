#!/bin/bash
# Isolation probe: a deliberately nosy "customer build". It only TRIES things and reports yes/no; it never prints file contents
# and never changes anything outside its own sandbox (two marker files that the agent's cleanup must remove).
R=()
say() { R+=("$1"); }
try() { # try <name> <command...>   -> "ALLOWED" if the command succeeds, "refused" otherwise
  local n="$1"; shift
  if "$@" >/dev/null 2>&1; then say "$n: ALLOWED"; else say "$n: refused"; fi
}

say "who: $(id -un) uid=$(id -u) groups=[$(id -Gn | tr ' ' ',')]"
say "cwd: $PWD"

# 1. Other users' files
for h in /Users/*; do
  u=$(basename "$h"); [ "$u" = "Shared" ] || [ "$u" = "apprtur-build" ] || [ "$u" = "Guest" ] && continue
  try "list $u home"                 ls "$h"
  try "read $u Documents"            ls "$h/Documents"
  try "read $u Apprtur data"         ls "$h/Library/Application Support/Apprtur"
  try "read $u Keychains folder"     ls "$h/Library/Keychains"
  try "read $u .ssh"                 ls "$h/.ssh"
done

# 2. Keychain
say "default keychain: $(security default-keychain 2>/dev/null | tr -d ' "')"
say "keychains: $(security list-keychains 2>/dev/null | tr -d ' "' | tr '\n' ' ')"
try "agent keychain item (service Apprtur)" security find-generic-password -s Apprtur

# 3. Tools and system
try "write into /Applications"                 touch /Applications/.probe
try "write into Xcode.app"                     touch /Applications/Xcode.app/.probe
try "write into shared toolchains"             touch /Users/Shared/apprtur/toolchains/.probe
try "write into /Users/Shared/apprtur"         touch /Users/Shared/apprtur/.probe
try "write into /Library/LaunchDaemons"        touch /Library/LaunchDaemons/.probe
try "sudo without password"                    sudo -n true
try "read /etc/sudoers.d (list)"               ls /etc/sudoers.d
try "read /etc/master.passwd"                  cat /etc/master.passwd

# 4. Other jobs and processes
say "other job folders visible: $(ls /Users/apprtur-build/jobs 2>/dev/null | wc -l | tr -d ' ')"
say "processes visible: $(ps -axo user | sort | uniq -c | tr -s ' ' | tr '\n' ';')"
AP=$(ps -axo pid,user,command | awk '$2!="apprtur-build" && /Apprtur/ {print $1; exit}')
[ -n "$AP" ] && try "read agent process environment (pid $AP)" bash -c "ps -E -p $AP | grep -q APPRTUR_"
try "task-port style: lldb attach agent"       bash -c "[ -n '$AP' ] && lldb -p $AP -b -o quit"

# 5. Environment: names only
say "env names: $(env | cut -d= -f1 | sort | tr '\n' ' ')"
say "secret-looking env names: $(env | cut -d= -f1 | grep -Ei 'token|secret|passw|key|credential' | tr '\n' ' ')"

# 6. Network
GW=$(route -n get default 2>/dev/null | awk '/gateway/ {print $2}')
say "gateway: ${GW:-unknown}"
[ -n "$GW" ] && try "reach router $GW by HTTP"  curl -s -m 3 -o /dev/null "http://$GW/"
try "reach the internet (example.com)"          curl -s -m 5 -o /dev/null https://example.com/
try "listen on a local port"                    bash -c "(exec 3<>/dev/tcp/127.0.0.1/22) 2>/dev/null"

# 7. Persistence: leave things behind that the agent's cleanup must remove
mkdir -p "$HOME/Library/LaunchAgents" 2>/dev/null
touch "$HOME/isolation-probe-marker" "$HOME/Library/LaunchAgents/com.probe.isolation.plist" 2>/dev/null
touch /tmp/isolation-probe-marker 2>/dev/null
say "left behind: ~/isolation-probe-marker, ~/Library/LaunchAgents/com.probe.isolation.plist, /tmp/isolation-probe-marker"
( nohup sleep 1234 >/dev/null 2>&1 & ) ; say "started a detached process: sleep 1234"

# 8. Disk: how much the job volume allows
say "job volume: $(df -h "$PWD" | tail -1 | tr -s ' ')"

for line in "${R[@]}"; do echo "error: PROBE $line"; done
exit 1
