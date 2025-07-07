# gh-switcher Comprehensive Test Plan

> **Version:** 1.0
> **Status:** Draft – ready for implementation
> **Maintainers:** Core CLI team (@you)

---

## 1. Purpose
Provide a pragmatic, risk-based testing strategy that guarantees data safety, reliable account switching, and rapid iteration while honouring the **test-rules** and overall project philosophy.

## 2. Scope
* **In-scope:** All Bash functions in `gh-switcher.sh`, configuration file I/O, CLI commands, helper scripts.
* **Out-of-scope:** External GitHub service availability (mocked), non-GitHub git profile management, UI/TUI concepts.

## 3. Test Suite Architecture
| Layer | Directory | Speed Target | Description |
|-------|-----------|--------------|-------------|
| **Unit** | `tests/unit/` | <200 ms / file | Pure function tests (no external commands). |
| **Service** | `tests/service/` | <500 ms / file | Functions calling `git`, `gh`, `gpg`, file I/O (mocked binaries). |
| **Integration** | `tests/integration/` | ≤5 s / file | End-to-end CLI workflows using real git repos & temp SSH keys. |
| **Nightly** | `tests/integration/@slow` | N/A | Long-running or cross-platform specs executed in nightly CI. |

Key rules (inherits from `test-rules.mdc`):
1. Every BATS file loads `helpers/test_helper` then **sets up isolated `$TEST_HOME`**.
2. No network calls – mock GitHub API via stub.
3. Tag slow specs with `@slow` so main CI can skip them.
4. Structure new helpers under `tests/helpers/` rather than duplicating code.

## 4. Risk-Based Prioritisation
| Priority | Failure Impact | Areas |
|----------|----------------|-------|
| **P0 – Data Integrity** | Corrupts or loses user data | File atomic writes, migrations, encoding/decoding |
| **P1 – Core Workflows** | Blocks daily work | `ghs switch`, `ghs add-user`, profile application |
| **P2 – Security & Permission** | Security leaks, incorrect auth | SSH key validation, gpg, input validation |
| **P3 – UX & Performance** | User confusion, slowness >100 ms | Dashboard output, list commands, large config perf |

## 5. Coverage Matrix
| Feature / Module | Unit | Service | Integration |
|------------------|------|---------|-------------|
| Base64 encode/decode | ✅ | – | – |
| Profile entry write/read | ✅ | – | – |
| User list CRUD | ✅ | – | ✅ |
| SSH key validation | ✅ | ✅ | ✅ |
| Git config application | – | ✅ | ✅ |
| GitHub auth detection | – | ✅ | ✅ |
| Project assignment | ✅ | – | ✅ |
| Migration v0→v2 | ✅ | – | ✅ |
| CLI `switch` | – | – | ✅ |
| CLI dashboard | – | – | ✅ (@slow) |

(✅ indicates a planned spec, not necessarily implemented yet.)

## 6. Detailed Test Specifications

### 6.1 P0 – Data Integrity (COMPLETED)
1. **encode/decode round-trip** – implemented in `tests/unit/test_profile_io.bats`.

> NOTE: Legacy *migration* and *atomicity* specs were removed with the v3 profile rewrite (no temp-file writes and no old formats). These items are no longer relevant and have been excised from the roadmap.

### 6.2 P1 – Core Workflows (IN PROGRESS)
1. **ghs_switch_command** – pending (`tests/integration/test_switch_command.bats` to be added).
2. **ghs_add_user_command** – implemented & passing.
3. **apply_user_profile** – covered by SSH integration tests.
4. **update_profile_field** – pending unit spec.
5. **ghs_assign_command** – pending (`tests/integration/test_project_assignment.bats`).

### 6.3 P2 – Security & Permission (PARTIAL)
1. **validate_ssh_key** – implemented & passing.
2. **get_user_by_id** – implemented & passing.
3. **validate_gpg_key** – pending service tests.

### 6.4 P3 – UX & Performance (NOT STARTED)
1. **dashboard_render (@slow)** – pending.
2. **list_users_perf** – optional perf harness.

## 7. Implementation Roadmap (rev 1)
- **Phase 1 (complete):** directory restructure, baseline unit/service/integration coverage, CI matrix, lint/test pre-commit.
- **Phase 2 (current):**
  1. Add switch / assign / gpg tests.
  2. Reach ≥80 % function coverage.
- **Phase 3:** Nightly `@slow` specs (dashboard + perf) and Windows runner.

## 8. Continuous Integration Enhancements
1. **Job matrix:** `shell={bash,zsh}` × `os={ubuntu-latest,macos-latest}`.
2. Cache `bats-core` binaries to cut runtime.
3. Upload `bats-format-tap` report for GitHub UI annotations.

## 9. Contribution Guidelines
* Follow **Coding Standards** and **Test Rules**.
* New features **MUST** include tests hitting at least unit + one higher layer.
* For risky refactors add **contract tests** to lock behaviour before change.

## 10. Glossary
* **Service test:** interacts with external binaries but stubs network/filesystem.