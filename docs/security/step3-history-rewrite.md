# Step 3 — Git history rewrite runbook

Verified on a throwaway `--mirror` clone on 2026-07-01: after the two passes
below, **0** of the 35 catalogued secret literals remained in history,
`terraform.tfstate` blobs went 1765 → 0, and `secret.env` files 16 → 0, while
HEAD retained real content (330 files). Tooling present: `git-filter-repo`
(`a40bce54`).

> The automated run stops here. **You (operator) run the force-push** after
> notifying collaborators — every clone diverges and must be re-cloned.

## Prerequisites

1. Step 1 (credential rotation) is done — history rewrite does **not** undo
   exposure of already-pushed secrets; only rotation does.
2. Step 2 scrub is committed on `main` (so the new clean HEAD is what survives).
3. All collaborators are told a force-push is coming.

## Commands

Run on a **fresh mirror clone**, never your working copy:

```bash
git clone --mirror https://github.com/tokamak-network/tokamak-infra.git tokamak-infra-clean.git
cd tokamak-infra-clean.git

# Pass 1 — drop secret files from ALL history
git filter-repo --force --invert-paths \
  --path-glob '*secret.env' \
  --path-glob '*.tfstate' \
  --path-glob '*.tfstate.backup' \
  --path-glob 'terraform/terraform.tfstate.d/'

# Pass 2 — scrub remaining secrets from surviving files
#   (.git-history-replacements.txt is in the repo root, gitignored — copy it here first)
git filter-repo --force --replace-text /path/to/.git-history-replacements.txt
```

## Verify BEFORE pushing (must all print 0)

```bash
ALL=$(git rev-list --all)
# no catalogued secret survives
while IFS= read -r l; do t="${l%%==>*}"; [ "${t#regex:}" = "$t" ] || continue; \
  c=$(git grep -lF "$t" $ALL 2>/dev/null | wc -l); [ "$c" = 0 ] || echo "LEFT: $t"; \
done < /path/to/.git-history-replacements.txt
# no tfstate / secret.env
git rev-list --all | xargs -I{} git ls-tree -r {} | grep -c tfstate
git log --all --name-only --pretty=format: | grep -cE '(^|/)secret\.env$'
```

## Force-push (OPERATOR, after team notice)

```bash
git push --force origin --all
git push --force origin --tags
```

Then: every collaborator deletes their clone and re-clones. Enable branch
protection on `main` (block force-push) **after** this, per Step 5.

## Cleanup

```bash
rm -f /path/to/.git-history-replacements.txt   # contains raw secrets
```
