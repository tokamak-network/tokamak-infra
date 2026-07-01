# Step 3 — Git history rewrite runbook

**Scope decision (operator):** repo is decommissioned. Keep only `main` + tags;
**delete all 196 `OR-*` / feature branches** on the remote. Deleted branches'
commits become unreachable, so their secrets vanish with them; `main` + tags are
rewritten to purge secrets that are also reachable from `main`
(confirmed: batch-submitter private key in 2 `main` commits, Auth0 secret in 1,
QuickNode key in 1; 35 `secret.env` appearances and 82 `tfstate` in `main`).

**Correction to an earlier note:** the remote is NOT `main`-only. GitHub has
**196 branches + 15 tags**, each carrying secrets in history. That is why the
recipe below both rewrites `main`+tags AND deletes the other branches.

End-to-end verified on a throwaway `--mirror` clone (2026-07-01): after the
recipe, refs = `main` + 15 tags, residual catalogued secrets = 0, `tfstate`
blobs = 0, `secret.env` files = 0, `main` HEAD intact (334 files).
Tooling present: `git-filter-repo` (`a40bce54`).

> The automated run stops here. **You (operator) run the force-push / mirror
> push** after notifying collaborators — the 196 branches disappear and every
> clone must be re-cloned.

## Prerequisites

1. Step 1 (credential rotation) — DONE.
2. Step 2 scrub committed on `main` (commit `1c3ed74`) and pushed.
3. Collaborators told: 196 branches will be deleted and history rewritten.
4. `.git-history-replacements.txt` (repo root, gitignored) is available.

## Recipe (order matters)

`git filter-repo` restores refs it processes, so **filter first, delete
branches second, then mirror-push.** Run on a fresh mirror clone, never your
working copy:

```bash
git clone --mirror https://github.com/tokamak-network/tokamak-infra.git tokamak-infra-clean.git
cd tokamak-infra-clean.git

# --- Pass 1+2: purge secrets from ALL history (main + tags + branches) ---
git filter-repo --force --invert-paths \
  --path-glob '*secret.env' \
  --path-glob '*.tfstate' \
  --path-glob '*.tfstate.backup' \
  --path-glob 'terraform/terraform.tfstate.d/'
git filter-repo --force --replace-text /path/to/.git-history-replacements.txt

# --- Then drop every branch except main (sticks only AFTER filter-repo) ---
git for-each-ref --format='%(refname)' refs/heads \
  | grep -v '^refs/heads/main$' \
  | while read r; do git update-ref -d "$r"; done
```

## Verify BEFORE pushing (all must be 0 / expected)

```bash
git for-each-ref refs/heads          # -> only refs/heads/main
git for-each-ref refs/tags | wc -l   # -> 15
ALL=$(git rev-list --all)
while IFS= read -r l; do t="${l%%==>*}"; [ "${t#regex:}" = "$t" ] || continue; \
  c=$(git grep -lF "$t" $ALL 2>/dev/null | wc -l); [ "$c" = 0 ] || echo "LEFT: $t"; \
done < /path/to/.git-history-replacements.txt
echo "$ALL" | xargs -I{} git ls-tree -r {} | grep -c tfstate      # -> 0
git log --all --name-only --pretty=format: | grep -cE '(^|/)secret\.env$'  # -> 0
git ls-tree -r refs/heads/main --name-only | wc -l                # -> ~334
```

## Push (OPERATOR, after team notice)

`--mirror` makes the remote match this repo exactly: rewritten `main`, 15 tags,
and the 196 branches deleted.

```bash
git push --mirror origin
```

Then: every collaborator deletes their clone and re-clones. Enable branch
protection on `main` (block force-push) afterwards, per Step 5.

## Cleanup

```bash
rm -f /path/to/.git-history-replacements.txt   # contains raw secrets
rm -rf tokamak-infra-clean.git
```
