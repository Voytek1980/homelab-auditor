#!/usr/bin/env bash
# =============================================================================
# audit-sweep.sh — Trigger a full audit cycle via Claude Code
# =============================================================================
# Invokes Claude Code headless with the audit-orchestrator agent context.
# The orchestrator reads evidence, signals, coverage map, and backlog,
# then decides what to audit this session.
#
# Usage:
#   audit-sweep                        # Full automated sweep
#   audit-sweep "Focus on network"     # Sweep with specific focus
set -euo pipefail

AUDITOR_DIR="/opt/auditor"
LOGS_DIR="${AUDITOR_DIR}/logs"
REPO_DIR="/home/voytek/repos/homelab-auditor"
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
LOG_PREFIX="[$TIMESTAMP]"

mkdir -p "$LOGS_DIR"

# Change to repo dir so Claude picks up CLAUDE.md, .claude/, .agent/
cd "$REPO_DIR" || {
    echo "$LOG_PREFIX ERROR: Auditor repo not found at $REPO_DIR" >> "${LOGS_DIR}/audit-sweep.log"
    exit 1
}

FOCUS="${1:-}"

# Build the prompt
PROMPT="You are the audit orchestrator. Run a full audit sweep cycle.

Read the current state:
- Coverage map: ${AUDITOR_DIR}/coverage/coverage-map.json
- Backlog: ${AUDITOR_DIR}/backlog/backlog.json
- Recent evidence: ${AUDITOR_DIR}/evidence/ (latest date directory)
- Recent signals: ${AUDITOR_DIR}/signals/ (today or latest .json)
- Recent findings: ${AUDITOR_DIR}/findings/ (for context)
- Recent journal: ${AUDITOR_DIR}/journal/ (for context)

Follow the audit orchestrator protocol:
1. Read coverage map and backlog
2. Check for recent signals (prioritize active incidents)
3. Identify coverage gaps (areas never audited or oldest)
4. Select 2-3 areas to audit this session
5. Execute audits using SSH to infrastructure hosts
6. Write findings to ${AUDITOR_DIR}/findings/
7. Write journal entry to ${AUDITOR_DIR}/journal/
8. Update coverage map and backlog
9. If CRITICAL findings: send ntfy alert"

if [ -n "$FOCUS" ]; then
    PROMPT="${PROMPT}

FOCUS OVERRIDE: The operator requested focus on: ${FOCUS}
Prioritize this area but still follow the protocol."
fi

echo "$LOG_PREFIX Starting audit sweep..." >> "${LOGS_DIR}/audit-sweep.log"

# Run Claude Code headless
REPORT=$(claude -p --dangerously-skip-permissions "$PROMPT" 2>>"${LOGS_DIR}/audit-sweep.log") || {
    echo "$LOG_PREFIX ERROR: Claude audit sweep failed with exit code $?" >> "${LOGS_DIR}/audit-sweep.log"
    exit 1
}

# Save the full report
REPORT_FILE="${AUDITOR_DIR}/reports/sweep-${TIMESTAMP}.md"
echo "$REPORT" > "$REPORT_FILE"

echo "$LOG_PREFIX Audit sweep complete. Report: ${REPORT_FILE}" >> "${LOGS_DIR}/audit-sweep.log"
echo "Audit sweep complete. Report saved to: ${REPORT_FILE}"
