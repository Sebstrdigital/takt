# Git evidence: what takt gates changed

Scope: all git repos under /Users/sebastianstrandberg/work/git (depth 3), `git log --all`. Read-only. Commits deduplicated by full sha; submodule-pointer-only commits in wrapper repos excluded (71 removed, they mirror submodule commits); kraken-rls-fix is a worktree of kraken-wrapper/kraken and merged with it; OB1 excluded (upstream fork, not takt).

Method caveat: classification is from commit subject plus `git show --numstat`, with 10 diffs read in full (uven 3088f50, 8eb3ff7; sepanel 0a04abf, dc63739; nettobrand 80d852c, e03be79; dikta 72d65b7, be0aee7, b759721; uven 1c3a9ca). "real bug" includes minor behavioral fixes. Treat shares as +/- 10 points.

## Overall

| Stage | Commits | Real bug | Cosmetic | Test-only | Docs/config | Real share |
|---|---|---|---|---|---|---|
| Verify fixes (`fix: BUG-*`, `fix: verify cycle`) | 50 | 40 | 10 | 0 | 0 | 80% |
| Review fixes (`fix: review*`, MF-*) | 109 | 73 | 15 | 7 | 14 | 66% |
| Local-validation fixes (`fix: local validation`) | 0 | - | - | - | - | none exist in any repo |

Story commits (`feat: US-`): 1164. Gate fixes per story: verify 0.043, review 0.094. Retro/changelog commits: 58, of which 53 touch only docs/config/json and 5 touch source or tests (cleanup of stale factories, mypy config, dotenv-cli, submodule bump).

Cross-stage regression found: nettobrand 80d852c (verify BUG-002) replaced the over-max shipping tier with `return 0`. Review commit e03be79 (same day, 2026-03-27) restored the heavy-freight fallback. So one verify fix introduced a real pricing bug and the review gate caught it. No fix commit in any repo was reverted by a `Revert` commit.

## Per repo

| Repo | Stories | Verify fixes (real) | Review fixes (real) | Retro |
|---|---|---|---|---|
| uven | 228 | 17 (13) | 32 (24) | 7 |
| dua-cs-agent/cs-agent-saas | 170 | 0 (0) | 2 (2) | 1 |
| nettobrand-wrapper/nettobrand | 166 | 8 (6) | 12 (10) | 1 |
| kraken-wrapper/kraken | 119 | 8 (5) | 18 (10) | 2 |
| dua-cs-agent/cs-agent | 109 | 0 (0) | 1 (0) | 0 |
| dikta | 93 | 5 (4) | 7 (7) | 4 |
| dua-cs-agent/cs-kb-agent | 55 | 0 (0) | 0 (0) | 0 |
| munin | 39 | 2 (2) | 11 (7) | 3 |
| takt | 31 | 0 (0) | 5 (1) | 6 |
| dua-erp | 24 | 1 (1) | 7 (3) | 6 |
| oribium/sepanel_oribium | 24 | 3 (3) | 5 (5) | 1 |
| mcp-servers | 22 | 0 (0) | 0 (0) | 0 |
| simplybrf-wrapper/mobile-app | 16 | 0 (0) | 1 (0) | 0 |
| nettobrand-wrapper | 12 | 0 (0) | 0 (0) | 8 |
| kraken-wrapper | 11 | 2 (2) | 2 (0) | 19 |
| nettobrand-wrapper/korpen | 10 | 2 (2) | 2 (1) | 0 |
| apisix-waf | 9 | 0 (0) | 2 (1) | 0 |
| dua-factory | 7 | 0 (0) | 0 (0) | 0 |
| simplybrf-wrapper/User-Web | 6 | 0 (0) | 1 (1) | 0 |
| dua-cs-agent | 5 | 0 (0) | 0 (0) | 0 |
| dua-pulse | 5 | 2 (2) | 0 (0) | 0 |
| simplybrf-wrapper/api | 3 | 0 (0) | 1 (1) | 0 |

### Repos where gates produced only cosmetic, docs or test changes

- takt: 5 review fixes, 4 docs-only (9ec22fb, edef67e, 6c212da, cf6ca4f). Only d14114f (install.sh loop) is behavioral. No verify stage recorded.
- dua-cs-agent/cs-agent: single review fix ffd97cd, moves `import json` to top level.
- simplybrf-wrapper/mobile-app: single review fix 847f042, gitignore plus CLAUDE.md wording.
- kraken-wrapper (eval tooling): 2 review fixes, both config/lockfile; 2 verify fixes are real (fail-fast on missing API key, ESM __dirname).
- apisix-waf: 1 of 2 review fixes cosmetic (879013f dedup refactor).
- dua-cs-agent, dua-cs-agent/cs-kb-agent, dua-factory, mcp-servers: stories exist, zero gate-fix commits (gate either found nothing or fixes were folded into story commits; unverified which).

## 10 most substantive gate-caught fixes

1. uven 3088f50 (review): add OIDC state parameter for CSRF protection, signed nonce cookie plus verification, +123 lines.
2. uven 8eb3ff7 (review): content-type allowlist for inline disposition plus nosniff, closes stored XSS via uploaded HTML/SVG.
3. uven 1c3a9ca (verify): email enumeration, leave redirect, lobby retry, participant count, with tests, 80 lines.
4. sepanel_oribium 0a04abf (review): cross-tenant FK guard and 32 KB cap applied to pre-parsed JSON as well as strings.
5. sepanel_oribium dc63739 (review): split WebSocket consumer groups so notifications are not delivered twice, guard error-path saves.
6. kraken-wrapper/kraken 484bea1f (review): timestamptz Date crash, numeric-coercion sweep, BYPASSRLS scoping.
7. kraken-wrapper/kraken 00a44251 (review): remove invite URL logging, add org_id guard to deleteEntity.
8. nettobrand e03be79 (review): restores heavy-order shipping fallback that verify fix 80d852c had removed (real pricing regression).
9. dikta 72d65b7 (review): data race, audioConverter now read under bufferLock.
10. dikta b759721 (review cycle 1, MF-1..4): browser child process was orphaned on app quit, added willTerminate observer; plus 3 more must-fixes.

Other strong candidates: uven 280f4a5 (webhook HMAC verification), uven cf83037 (N+1 unread query), dikta be0aee7 (verify: hidden WKWebView window made getUserMedia hang), munin bea8b2b (real cross-chunk embed batching).

## 10 most trivial

1. dua-cs-agent/cs-agent ffd97cd: move `import json` to top (1 line).
2. dua-erp e91eb93: remove duplicate header in CLAUDE.md (docs only).
3. dua-erp 44f1e82: remove duplicate NullPool setting in alembic env.py (4 deletions).
4. nettobrand 748e220: fix a docstring, use getConfig().
5. kraken-wrapper/kraken dfccd5f: correct misleading JSDoc in an e2e test.
6. kraken-wrapper/kraken aa61f9e (verify): remove leftover Clerk references from comments.
7. uven a720372: remove duplicate CSS block (73 deleted lines).
8. dikta 6631422 (verify): remove dead stub subscription in App.xaml.cs.
9. munin 4fc0ae2: iterator type annotations and E303 lint.
10. takt edef67e: one-line CLAUDE.md wording update, plus takt 9ec22fb, 6c212da (docs only).

## Open questions

- No `fix: local validation` subjects exist. If the stage exists, its fixes may be squashed into story commits.
- Story commits may already contain fixes made before the gate ran; that is not visible from history.
- Verify-stage commits in old takt use `fix: BUG-*`; the `fix: verify cycle N` format appears only in dikta (be0aee7), so the newer format is mostly untested in history.