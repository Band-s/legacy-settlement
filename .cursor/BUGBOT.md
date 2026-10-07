# Bugbot rules (Northwind demo)

Demo code for the fictional Northwind Commerce. Bugbot reads this file (root
`.cursor/BUGBOT.md`, plus any nested file on the path to a changed file).
`.cursor/rules/*.mdc` does not apply to Bugbot. Comment `bugbot run verbose=true`
on a PR to see which rules loaded.

## Shared

1. **Template input (HIGH).** Request data (`req.body`, `req.query`, `req.params`,
   headers) must never reach a lodash `_.template` or `shared-utils`
   `renderTemplate()` template string or options (`variable`, `imports`,
   `sourceURL`).
2. **Protected paths (HIGH).** A change under `src/auth/**` or `src/payments/**`
   needs the named human reviewers in that directory's `APPROVAL_POLICY.md`. Say
   so even if the change looks safe.
3. **Dependencies (MEDIUM).** A `package.json` dependency change must include the
   matching lockfile. Flag major upgrades, new runtime dependencies, and git
   dependencies on a mutable ref (for example `#main`).
4. **Error handling (MEDIUM).** Public endpoints must answer invalid input with a
   4xx JSON `{ error }`. Flag a thrown error that becomes Express's default 500
   HTML stack page.
5. **Secrets (HIGH).** Never log, return or commit a sign-in token, an API key or
   card data.

## This repo

SETTLE01 (`cobol/SETTLE01.cbl`) is the source of truth. Do not edit the COBOL,
the VB6, the inputs or the golden files (`data/golden/*.out`) unless the task
explicitly says to recapture goldens. Flag a Java port that changes fee
arithmetic or skips a characterization case.
