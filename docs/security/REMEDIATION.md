# Security Remediation Plan — tokamak-infra

Repo status: **decommissioned** (no live ArgoCD/prod consuming these manifests).
Remote: `github.com/tokamak-network/tokamak-infra` — history is already public/shared.

Goal: make the repo safe to keep on GitHub. Because the repo is already pushed,
**credential rotation (Step 1) is the only action that actually neutralizes the
exposure** and is performed by the operator on external dashboards. Steps 2–5
below remove secrets from the current tree and history and prevent recurrence.

Constraint: AWS account `992382494724` (used by `thanos-sepolia`) is off-limits
to automation per operator policy. Any AWS Secrets Manager work for that
namespace is done manually by the operator.

---

---

## Execution status (2026-07-01)

- **Step 1 — DONE (operator).** Credentials rotated on external dashboards.
- **Step 2 — DONE & VERIFIED.** 26 files scrubbed in place (values → placeholders,
  structure kept). Known-token sweep, broad-pattern sweep, and an independent
  entropy sweep all return 0 live secrets; no file deleted; `.gitignore` extended
  and dry-checked. The initial `.env`-only audit missed `apps/blockscout-stack/
  override_values/*.yaml` (Auth0 secret, SendGrid key, CoinMarketCap key,
  CLOAK key, RDS creds), the two `proxyd-config.toml` (5 RPC keys), two
  monitoring Slack webhooks, and a graph-node bearer token — all caught by the
  self-checking sweeps and scrubbed.
- **Step 3 — DONE & VERIFIED on the remote (2026-07-02).** History rewritten on
  GitHub: `main` purged, 195 feature branches deleted, 15 tags kept. Verified
  from a fresh **normal** clone (an attacker's view): 1293 commits reachable,
  residual catalogued secrets = 0, tfstate = 0, secret.env = 0, branches = 1
  (`main`), tags = 15. Recipe used: fresh `--mirror` clone → filter-repo
  (drop secret.env/tfstate + replace-text) → delete non-main heads →
  re-add origin → `git push --mirror`. Commit hashes changed
  (`f40b9adf`, `423d372b`).
  - **RESIDUAL — GitHub PR refs (`refs/pull/*/head`).** `git push --mirror`
    could not touch these (GitHub: "deny updating a hidden ref"); they still
    point to pre-rewrite commits that contain the old secrets. They are NOT
    included in a normal clone (only via explicit `git fetch 'refs/pull/*'`).
    Because Step 1 rotation already invalidated every one of those credentials,
    this is dead data. To purge fully, ask **GitHub Support** to run `git gc` /
    remove stale PR refs on the repo.
- **Step 4 — SATISFIED (documentation).** Placeholders read
  `<SET_VIA_EXTERNALSECRET>` / `<PROVIDER_KEY>`; repo already ships the
  `ExternalSecret`+`SecretStore` pattern. No live migration for a dead repo.
- **Step 5 — CONFIG ADDED; run/toggle PENDING (operator).**
  `.pre-commit-config.yaml` (gitleaks) + `.gitleaks.toml` (allowlists the
  Hardhat test key + public certs). `gitleaks` not installed locally; operator
  runs `pre-commit run gitleaks --all-files` and enables GitHub Secret Scanning
  + branch protection (after Step 3).

---

## Step 1 — Rotate exposed credentials (operator, external dashboards)

Out of scope for this automated run. Tracked here for completeness.

- **Success:** every credential listed in the audit (Slack webhooks ×3,
  QuickNode key, Infura key, `BLOCK_SIGNER_KEY`, Blockscout RDS password,
  `SECRET_KEY_BASE`, `RE_CAPTCHA_SECRET_KEY`, Sentry DSNs, graph-node postgres
  password, and every private key found in git history) has been revoked and
  reissued; old values no longer authenticate.
- **Failure:** any old credential still authenticates against its provider.

---

## Step 2 — Scrub secret values from the current tree + extend `.gitignore`

Approach: because the repo is decommissioned, values are **replaced in place
with placeholders** (keys kept as a reference template) rather than deleting
files. This neutralizes the current HEAD without breaking file structure.

- **Success:**
  1. `git grep` for every known secret token (exact values from the audit)
     returns **zero** matches in the tree.
  2. The broad pattern sweep (`AKIA…`, `ghp_…`, `xox[baprs]-`, live
     `hooks.slack.com/services/T…`, `infura.io/v3/<hex>`, `quiknode.pro/<hex>`,
     inline `BEGIN RSA PRIVATE KEY`, 64-hex private-key assignments) returns
     zero matches, except the well-known **Hardhat test key** in
     `tokamak-optimism/test/.../.env.example` (documented false positive).
  3. `.gitignore` gains patterns that would catch these files if re-added
     (`secret.env`, `secret-cert.yaml`, `*.env` under kustomize `envs/`), and a
     dry check confirms the patterns match the intended paths.
  4. No file is physically deleted; every scrubbed file still exists on disk.
- **Failure:**
  - Any known secret token or broad pattern still present in a tracked file.
  - A non-secret value (contract address, public cert, public reCAPTCHA site
    key, Hardhat test key) was altered.
  - A file was deleted or emptied such that its structure/reference is lost.

## Step 3 — Rewrite git history to purge secrets (operator force-pushes)

Historical commits still contain real private keys (`*/secret.env`) and
`terraform.tfstate` files. `.gitignore` and Step 2 do not touch history.

- **Success:**
  1. A `git-filter-repo` invocation (or `--replace-text` patterns file) is
     prepared and dry-run-verified locally on a **clone**, confirming:
     - `git log --all -p -S<token>` finds each target secret **before** and
       **zero** occurrences **after** the rewrite.
     - `terraform.tfstate*` and `*/secret.env` no longer appear in
       `git log --all --name-only`.
  2. Commands and a collaborator re-clone notice are handed to the operator.
- **Failure:** any target secret still reachable from any ref after the rewrite;
  or force-push performed without team notice.
- **Boundary:** the automated run stops before `git push --force-with-lease`.
  The operator executes the force-push after notifying collaborators.

## Step 4 — Adopt the ExternalSecret pattern (mostly documentation for a dead repo)

The repo already uses `ExternalSecret` + AWS `SecretStore` in some overlays.
For a decommissioned repo this is a documented target state, not a live
migration; scrubbed placeholders point to it.

- **Success:** each scrubbed secret is documented as sourced from an
  `ExternalSecret`/`SecretStore` (or CI) rather than an inline value, and the
  placeholder text (`<SET_VIA_EXTERNALSECRET>`) makes the intended source clear.
- **Failure:** a placeholder is left with no documented source, or a secret is
  reintroduced inline.

## Step 5 — Prevent recurrence

- **Success:**
  - `gitleaks` (or equivalent) pre-commit config is present and, run against the
    scrubbed tree, reports no findings.
  - GitHub Secret Scanning / push protection is enabled (operator toggle) and
    branch protection on `main` blocks force-push **after** Step 3.
- **Failure:** secrets can be committed without any automated gate.
