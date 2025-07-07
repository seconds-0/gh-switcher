# Review – feat/test-suite branch & Testing Rules

_Date: 2025-??-??_

## 1. Scope Reviewed
* New helpers: `tests/helpers/*`
* BATS test files: `test_profile_io.bats`, `test_ssh_integration.bats`, `test_user_management.bats`
* CI workflow: `.github/workflows/ci.yml`
* Updated script internals (`gh-switcher.sh`)
* Newly minted `TEST-Rules.md` and `.cursor/rules/test-rules.mdc`

## 2. Strengths
1. **Isolation** – `$TEST_HOME` pattern prevents pollution of a real environment.
2. **Comprehensive Edge-cases** – SSH key validation, permissions, malformed keys, duplicate users.
3. **CI Pipeline** – single workflow covers lint → BATS → ShellCheck; runs green on both local and GitHub runners.
4. **Rule-Driven** – A canonical rule file instructs AI contributors, reducing churn.
5. **User UX** – `list_users` now surfaces `[HTTPS]` / `[SSH: …]` status, mirroring tests.

## 3. Issues / Risks
| ID | Severity | Description |
|----|----------|-------------|
| P0-001 | HIGH | Two competing code paths create different profile formats (simplified v2 vs v3). |
| P1-002 | MEDIUM | `cmd_add_user` bypasses new SSH logic; may diverge from `add_user` behaviour tested. |
| P1-003 | MEDIUM | `list_users` complexity O(N²); benign now, but smells. |
| P2-004 | LOW | `encode_profile_value` lacks `--wrap=0`; very long strings will wrap. |
| P2-005 | LOW | No path sanitisation for newline injection in profile lines. |
| P3-006 | LOW | `validate_ssh_key` header check easy to bypass with crafted file. |

## 4. Recommendations
1. **Unify profile format** – migrate tests & helpers to v3 and deprecate v2.
2. **Single source of CLI truth** – wrap CLI `cmd_*` functions around core helpers, not duplicates.
3. **Performance pass** – cache profile status inside `list_users`.
4. **Harden encoding** – add `base64 --wrap=0` and input sanitisation.
5. **Security sweep** – stricter key validation (openssh-parser or `ssh-keygen -l`).
6. **CI Matrix** – add macOS runner to catch BSD vs GNU tool diffs.

## 5. Next Steps
* Open tickets for each risk above and tag with corresponding P# ID.
* Draft migration plan for v3 profile format.
* Extend `TEST-Rules.md` to reference nightly `@slow` job once implemented.

---

_Reviewer:_ **AI Senior Engineer** 