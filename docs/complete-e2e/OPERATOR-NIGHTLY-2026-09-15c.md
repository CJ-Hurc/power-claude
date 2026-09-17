# continue-after-DENIED — honest certify/replay (once)

Prior: cells drained (outstanding=0) but certificate DENIED.

## Attempt (2026-09-15 ~20:12 MT)
- `run.sh replay --full` → passed=false; clean-room outstanding=28 (LEASED/OPEN collision with concurrent walkers)
- `run.sh certify --full` → **DENIED**
  - reviewers pending/stale
  - clean_replay_not_passed
  - proof_stale_after_source_change
  - unproven_required=28 during certify race
- Never invented CERTIFIED. No ALLOW_UNPROVEN.

## Hold
Ship-gate open until clean-room replay is fixed-point with no concurrent lease races + red-team files land.
