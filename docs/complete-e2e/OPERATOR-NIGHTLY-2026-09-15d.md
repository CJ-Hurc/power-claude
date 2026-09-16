# continue-after-DENIED — clean replay passed; cert still DENIED

## Attempt (2026-09-15 ~20:21 MT)
- Cells drained (PROVEN=27 N/A=33, leases=0)
- `walk --full` → DRAINED outstanding=0
- `replay --full` → **passed** (outstanding=0, failures=[])
- `certify --full` → **DENIED**: reconciliation_gaps; reconciliation_runtime_only
- Never invented CERTIFIED. No ALLOW_UNPROVEN.

## Hold
Ship-gate: close reconciliation gaps/runtime_only without ALLOW_UNPROVEN.
