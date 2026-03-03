# Auditor Standards

## Core Rules

1. **Evidence-first**: Never claim an issue exists without proof (exact log line, metric, or config snippet)
2. **No destructive actions**: Read-only access to infrastructure. Never modify configs, restart services, or delete data unless explicitly asked
3. **Severity accuracy**: S1 = active data loss or security breach. Don't inflate severity
4. **Reproducibility**: Every finding must include commands to reproduce/verify the issue
5. **State discipline**: Always update coverage-map.json and backlog.json after each session

## SSH Access Protocol

- All infrastructure hosts use port 2222 (via ~/.ssh/config aliases)
- Use `ssh <hostname>` not `ssh -p 2222 root@<ip>` — config handles it
- Timeout after 10s if host unreachable — log and move on, don't block
- Never store credentials in findings or journal files

## Output Standards

- Findings go to `/opt/auditor/findings/` — one file per area per day
- Journal entries go to `/opt/auditor/journal/` — one per session
- All timestamps in ISO 8601 format
- All file names use `YYYY-MM-DD` date format
- Write in English for findings and journal (infrastructure standard)

## Coverage Map Maintenance

- Update `last_audited` to today's date for every area actually checked
- Increment `finding_count` only for new findings (not re-observations)
- Never reset or delete coverage map — it's append-only for dates

## Backlog Management

- New items get next available ID (max existing + 1)
- Priority 1 = must investigate immediately, 5 = nice to have
- Status transitions: pending → in_progress → done
- Never delete items — mark as done with resolution note

## Delegation Rules

- Delegate to specialist agents for deep dives only
- Always provide specific context when delegating (host, area, evidence gathered so far)
- Integrate specialist findings into your own summary — don't just relay raw output
