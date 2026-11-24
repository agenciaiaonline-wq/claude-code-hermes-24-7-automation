#!/usr/bin/env bash
# ==============================================================================
# 24/7 Autonomous Agency Watchdog & Hardware Memory Guardian (Example)
# Run every 60 seconds via cron: * * * * * /path/to/hermes_watchdog.example.sh
# ==============================================================================

set -u

LOG_FILE="${WATCHDOG_LOG_FILE:-/var/log/hermes_watchdog.log}"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$BASE_DIR/docker/docker-compose.example.yml}"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$TIMESTAMP] $1"
}

# 1. Recover OmniRoute AI Gateway (127.0.0.1:20128)
if ! curl -s --max-time 3 http://127.0.0.1:20128/health > /dev/null 2>&1; then
    log "[WARN] OmniRoute unresponsive. Restarting omniroute.service..."
    sudo systemctl restart omniroute 2>/dev/null || systemctl --user restart omniroute 2>/dev/null || true
fi

# 2. Recover Docker Core Containers
if command -v docker > /dev/null 2>&1 && [ -f "$COMPOSE_FILE" ]; then
    RUNNING_CONTAINERS="$(docker ps --format '{{.Names}}' 2>/dev/null || true)"
    for svc in agency_postgres agency_redis agency_n8n agency_waha agency_qdrant; do
        if ! echo "$RUNNING_CONTAINERS" | grep -q "^${svc}$"; then
            log "[WARN] Container $svc stopped. Reviving via docker compose..."
            docker compose -f "$COMPOSE_FILE" up -d "${svc#agency_}" 2>/dev/null || true
        fi
    done
fi

# 3. Recover Hermes Agent tmux session
if command -v tmux > /dev/null 2>&1; then
    if ! tmux has-session -t hermes-agent 2>/dev/null; then
        log "[WARN] Hermes tmux session absent. Respawning..."
        tmux new-session -d -s hermes-agent 'hermes chat --yolo --accept-hooks' 2>/dev/null || true
    fi
fi

# 4. Recover HTTP-to-Tmux Task Bridge (:5050)
if ! curl -s --max-time 2 http://127.0.0.1:5050/health > /dev/null 2>&1; then
    log "[WARN] Task Bridge (:5050) down. Restarting..."
    pkill -f "hermes_task_bridge.py" 2>/dev/null || true
    nohup python3 "$BASE_DIR/scripts/hermes_task_bridge.py" > /tmp/task_bridge.log 2>&1 &
fi

# 5. Hardware Memory Guardrail (<400 MiB Free RAM Threshold)
FREE_RAM_MB="$(free -m | awk '/^Mem:/{print $7}')"
if [ -n "$FREE_RAM_MB" ] && [ "$FREE_RAM_MB" -lt 400 ]; then
    log "[ALERT] Available RAM critical (${FREE_RAM_MB} MiB < 400 MiB). Reclaiming safe caches..."
    pkill -f "chrome-sandbox" 2>/dev/null || true
    sync
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
    fi
fi
