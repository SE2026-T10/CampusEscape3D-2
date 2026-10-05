# Build and Release

This page covers how Campus Escape 3D is validated, tested and built, both locally and by GitHub Actions, and how to make a release.

## What's pinned

| Thing | Value | Where |
|---|---|---|
| Godot | 4.7.2 stable, official build | `GODOT_VERSION` in `.github/workflows/build.yml`; checked by `tools/ci/validate.sh` and `tests/test_scene.gd` |
| Godot download | `Godot_v4.7.2-stable_linux.x86_64.zip` from `github.com/godotengine/godot-builds` releases, checked against the release's `SHA512-SUMS.txt` | `tools/ci/setup_godot.sh` |
| Export templates | `Godot_v4.7.2-stable_export_templates.tpz` from the same release, same checksum check; only the Windows x64 templates are kept | `tools/ci/setup_godot.sh` |
| Export preset | "Windows Desktop": x86_64, release, `.pck` next to the `.exe`, `tests/*` and `tools/*` excluded | `export_presets.cfg` |
| Game version | `application/config/version` (e.g. `1.0.0`), with the preset's file and product versions at `1.0.0.0` | `project.godot`, `export_presets.cfg`; checked by `tools/ci/validate.sh` |
| CI runner | `ubuntu-24.04` | workflow |

No secrets are needed or stored. The release step uses the workflow's own short-lived `GITHUB_TOKEN`.

## The steps (the same locally and in CI)

| Script | What it does | Fails when |
|---|---|---|
| `tools/ci/setup_godot.sh` | downloads Godot and the export templates, verifies their SHA-512 checksums, installs the templates; prints the Godot path | a download fails or a checksum doesn't match |
| `tools/ci/validate.sh` | checks the exact Godot version, imports the project, compiles every script (`tools/ci/check_scripts.gd`), checks the version numbers (and the tag, on a tag build) | wrong Godot; import errors; a script doesn't compile; versions don't match |
| `tools/ci/run_tests.sh` | runs the full test suite (`tests/test_scene.tscn`) and the game-flow run with real scene changes (`tools/qa_flow.gd`), headless | the suite doesn't exit 0 or print "All tests passed"; any script error; the flow run doesn't pass |
| `tools/ci/export_windows.sh` | exports the Windows x64 release build and zips it as `dist/CampusEscape3D-<version>-windows-x64.zip` | export fails or logs an error; no `.exe` or `.pck`; the `.exe` isn't a Windows program; the main scenes are missing from the pack; tests or tools ended up in it |

Logs go to `ci-logs/`, and the build goes to `build/` and `dist/`. Git ignores all three folders.

### Run it locally (Linux, or WSL on Windows)

```
export GODOT="$(bash tools/ci/setup_godot.sh | tail -n 1)"   # or point GODOT at your own Godot 4.7.2
bash tools/ci/validate.sh
bash tools/ci/run_tests.sh       # about 4 minutes
bash tools/ci/export_windows.sh
```

### Build from the Godot editor (Windows)

1. **Install the export templates:** Editor → Manage Export Templates → Download and Install, for 4.7.2.
2. **Export:** Project → Export → **Windows Desktop** → Export Project → `build/CampusEscape3D.exe`, with **Export With Debug** unticked.
3. **Ship:** `build/` then holds `CampusEscape3D.exe` and `CampusEscape3D.pck`. Ship both together.

## GitHub Actions (`.github/workflows/build.yml`)

| Event | What runs |
|---|---|
| push to `Development` or `main`, pull request into them, or **Run workflow** by hand | **Validate and test** → **Export Windows x64** (uploads the build as an artifact) |
| push of a tag `vX.Y.Z` | the same, then **GitHub Release**: creates the release for the tag with the zipped build and `docs/release-notes/vX.Y.Z.md` |

**Failure rules:**
- Each job stops at its first failing step.
- The export job runs only if validation and tests passed.
- The release job runs only if the export passed.

**Downloading a build:** open the workflow run on GitHub → **Artifacts** → `CampusEscape3D-<version>-windows-x64`. It is kept for 30 days. Test and export logs are attached as `test-logs` and `export-logs`.

**Speed:** the Godot download (about 60 MB) and the Windows templates are cached between runs. The first run downloads the full 1.3 GB template archive once.

## Release process

1. **Start from a green `Development`:** the latest workflow run on the commit you want to release has passed.
2. **Bump the version** (for example 1.1.0):
   - `project.godot`: `config/version="1.1.0"`;
   - `export_presets.cfg`: `application/file_version="1.1.0.0"` and `application/product_version="1.1.0.0"`.
3. **Write the release notes:** `docs/release-notes/v1.1.0.md`.
4. **Commit and push** to `Development`, then wait for the workflow to pass.
5. **Tag that commit and push the tag:**
   ```
   git tag -a v1.1.0 -m "Campus Escape 3D 1.1.0"
   git push origin v1.1.0
   ```
6. **Let the tag build finish.** It checks that the tag matches the project version, runs everything again, and publishes the release with the Windows zip.
7. **Check the release:** download the zip from the release page and run the manual part of `docs/qa/REGRESSION_CHECKLIST.md` on Windows.

The release is reproducible from the tag:
- the same Godot build and templates (checked by checksum);
- the same scripts, run by the same pipeline.

The `.exe` and `.pck` aren't byte-for-byte identical between builds, because the pack records file times. The game they contain is the same.

**Undoing a bad tag:**
1. Delete the release on GitHub.
2. Delete the tag: `git push origin :refs/tags/vX.Y.Z` and `git tag -d vX.Y.Z`.
3. Fix the problem and tag again.

## MVP release: v1.0.0

The project is at version `1.0.0`, and the release notes are in `docs/release-notes/v1.0.0.md`.

To publish:
1. Commit and push to `Development`.
2. Wait for the **Build** workflow to pass on that commit.
3. Tag the commit:
   ```
   git tag -a v1.0.0 -m "Campus Escape 3D 1.0.0 (MVP)"
   git push origin v1.0.0
   ```

The tag build runs every check again and publishes the GitHub Release with the Windows zip.
