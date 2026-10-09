# Phase 15 — Automated Build Pipeline and MVP Release

This phase adds a GitHub Actions workflow that validates the project, runs the automated tests, exports the Windows x64 build, uploads it as an artifact and, on a version tag, publishes a GitHub Release.

It also sets the version to 1.0.0, documents the release process (`docs/BUILD.md`) and rewrites the README.

**Status (when this phase was written):** the workflow had **not run on GitHub yet**. That session had no write access to the repository, so it couldn't push. Every pipeline script was run locally instead (results below), and the workflow file passed `actionlint`.

**Status update (2026-10-09, release validation):** the branch was pushed and the first run, [Build #1](https://github.com/SE2026-T10/CampusEscape3D-2/actions/runs/37272574230) on `15b3ebf`, **passed**: Validate and test 4 m 16 s, Export Windows x64 39 s, total 5 m 03 s. It uploaded `CampusEscape3D-1.0.0-windows-x64` (37.5 MB, sha256 `06a855cc…2d4aa7`), `test-logs` and `export-logs`. That artifact was downloaded, its SHA-256 matched GitHub's digest, and it was run on Windows 10 (see `docs/FINAL_REPORT.md`). Steps 1 and 2 of the to-do list below are done; step 3 (tag `v1.0.0`) is not. The only annotations are GitHub's Node.js 20 deprecation warnings for the `@v4` actions.

## What was added

| File | Purpose |
|---|---|
| `.github/workflows/build.yml` | the workflow: triggers, jobs, caching, artifacts, release |
| `tools/ci/setup_godot.sh` | downloads official Godot 4.7.2 and the export templates, verifies SHA-512 checksums, installs the Windows x64 templates |
| `tools/ci/validate.sh` | exact Godot version, clean import, every script compiles, version numbers (and tag) consistent |
| `tools/ci/check_scripts.gd` | loads every GDScript in its own process and fails on a compile error |
| `tools/ci/run_tests.sh` | the full test suite plus the game-flow QA run, headless |
| `tools/ci/export_windows.sh` | Windows x64 release export, checks of the build, zip |
| `docs/BUILD.md` | build, CI and release process |
| `docs/release-notes/v1.0.0.md` | MVP release notes (used as the GitHub Release text) |
| `project.godot` | `application/config/version="1.0.0"` |
| `.gitignore` | `ci-logs/`, `dist/` |
| `README.md` | restructured with every section the brief requires |

## The workflow

**Triggers:**
- push to `Development` or `main`;
- pull request into `Development` or `main`;
- push of a tag `vX.Y.Z`;
- manual run.

**Jobs:**
1. **Validate and test.** Steps: checkout → cached Godot setup → `validate.sh` → `run_tests.sh`. Logs are uploaded even if a step fails.
2. **Export Windows x64.** Runs only after job 1 passes. Steps: checkout → setup → `validate.sh` (to import) → `export_windows.sh`. It uploads the build as the artifact `CampusEscape3D-<version>-windows-x64` (30 days) and the export log.
3. **GitHub Release.** Tags only, after job 2. It zips the artifact and runs `gh release create <tag>` with the release notes. It has `contents: write` and uses the job's `GITHUB_TOKEN`.

**What fails the workflow:**
- the wrong Godot version;
- a checksum mismatch;
- import errors, or a script that doesn't compile;
- a project, preset or tag version mismatch;
- any failing test or script error in the test run;
- the flow run not passing;
- an export error;
- a missing `.exe` or `.pck`, or an `.exe` that isn't a Windows program;
- main scenes missing from the pack, or tests or tools inside it.

**Secrets:** none. The workflow default is `contents: read`; only the release job gets `contents: write`.

## Local verification (2026-10-05)

The same scripts the workflow runs were tested on a fresh clone of the branch, with an empty Godot cache and no export templates installed (Linux, Ubuntu 24.04, 2 vCPUs).

| Step | Result |
|---|---|
| `setup_godot.sh`, first run | downloaded the editor and the 1.28 GB template archive; both SHA-512 checksums OK; 4.7.2 Windows templates installed; 18 s |
| `setup_godot.sh`, cached | 1 s, no downloads |
| `validate.sh` | Godot 4.7.2.stable.official.ed1daf0bf; import clean; `CHECK SCRIPTS PASSED (71 scripts)`; version 1.0.0; `VALIDATION PASSED` |
| `run_tests.sh` | `All tests passed (… Phase 14 QA).`; `QA FLOW PASSED (15 checks, 4 levels loaded)`; `TESTS PASSED`; 232 s |
| `export_windows.sh` | `CampusEscape3D.exe` 109,127,680 bytes (Windows "MZ" executable), `CampusEscape3D.pck` 589,300 bytes; main scenes present, no tests or tools in the pack; `dist/CampusEscape3D-1.0.0-windows-x64.zip` 38 MB |
| `actionlint` 1.7.12 (with shellcheck 0.11.0) | no findings |
| `shellcheck tools/ci/*.sh` | no findings |

**The pipeline fails when it should.** Each case below was tried on purpose, and each failed with a clear `::error::` message:

| Broken on purpose | Result |
|---|---|
| a parse error in a script | `validate.sh` exit 1: "Errors while importing the project" |
| a failing test (wrong expected engine version) | `run_tests.sh` exit 1: "Test suite failed (exit 1)" |
| tag `v9.9.9` on version 1.0.0 | `validate.sh` exit 1: "Tag v9.9.9 does not match the project version v1.0.0" (tag `v1.0.0` passes) |
| preset file version 0.9.0.0 | `validate.sh` exit 1: "export_presets.cfg application/file_version is '0.9.0.0', expected '1.0.0.0'" |
| export filter no longer excluding tests and tools | `export_windows.sh` exit 1: "Tests or tools were exported into the pack" |

**A bug found while testing locally:** the first version of the pack check looked for `res://` paths, but the pack's file index stores paths without that prefix, and exported scenes appear as `<path>.remap`. The check now looks for the index entries.

**The Windows executable was not run**, because there is no Windows machine here. Running it is the first manual check after the first CI build.

## To do (by the user)

1. **Push the branch to `Development`.** Don't push to `main`. Then open the repository's **Actions** tab and check that the **Build** run passes. This is the first real CI run.
2. **Download the artifact** `CampusEscape3D-1.0.0-windows-x64` and run it on Windows. Work through `docs/qa/REGRESSION_CHECKLIST.md` part 2.
3. **Tag the release.** When the run is green:
   ```
   git tag -a v1.0.0 -m "Campus Escape 3D 1.0.0 (MVP)"
   git push origin v1.0.0
   ```
   Then check that the tag run publishes the GitHub Release.

## Known limitations

- **No CI run yet:** the workflow hasn't run on GitHub. It may need adjustments that only show up on GitHub's runners, such as the first cache download or an action version.
- **Windows x64 only.** The executable is not code-signed.
- **Runtime per run:** the test job runs the full suite in real time, about 4 minutes, plus about 1 minute for the flow run.
- **First run is slower:** it downloads the 1.3 GB template archive once; later runs use the cache.
- **Builds aren't byte-for-byte identical** (file times in the pack). The tag pins the source, the Godot build and the templates.
