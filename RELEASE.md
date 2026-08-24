# Releasing

Releases are automated with
[release-please](https://github.com/googleapis/release-please). Version numbers
come from commit messages, not from a manual bump. A release always ties
together three things that must match: `dist.version` in `builder-config.yaml`,
the git tag (`v<version>`), and the image tag pushed to GHCR.

> [!NOTE]
> You can find the OpenTelemetry contrib release dates here: [https://github.com/open-telemetry/opentelemetry-collector/blob/main/docs/release.md#release-schedule](https://github.com/open-telemetry/opentelemetry-collector/blob/main/docs/release.md#release-schedule)


## Cutting a release

1. Land work on `main` using [Conventional
   Commits](https://www.conventionalcommits.org/) (see below).
2. `release-please.yaml` maintains an open PR titled
   `chore(main): release <version>`. It contains the `dist.version` bump, the
   `version.txt` bump, and the `CHANGELOG.md` entries for everything unreleased.
   The PR stays open and updates itself as more work lands.
3. **Merge that PR when you want to release.** There's no schedule — the PR is a
   queue you drain on your own timing.
4. Merging re-triggers `release-please.yaml`, which creates tag `v<version>` and
   the GitHub release.
5. The tag push triggers `build-and-publish.yaml`, which verifies the tag
   matches `dist.version`, builds the image, runs the smoke test, and pushes it
   to GHCR tagged `<version>`, `<version>-<sha>`, and `latest`.

Nothing is published to GHCR until a release tag exists. Pushes to `main` and
pull requests build the image and run the smoke test as a gate, but do not push.

## Commit message format

The version bump is derived from commit messages since the last release:

| Commit prefix | Effect |
| --- | --- |
| `fix:` | patch bump (0.1.0 → 0.1.1) |
| `feat:` | minor bump (0.1.0 → 0.2.0) |
| `feat!:` / `BREAKING CHANGE:` in body | major bump (0.1.0 → 1.0.0) |
| `chore:`, `docs:`, `ci:`, `refactor:`, `test:` | no release |

If PRs are squash-merged, the **PR title** becomes the commit message on `main`,
so the title is what must be conventional. `lint-pr-title.yaml` enforces this on
every PR — otherwise a malformed title fails nothing and simply gets skipped by
release-please, which looks identical to "no release was due".

While the version is below `1.0.0`, a `feat!:` bumps the minor rather than
jumping to `1.0.0`. Cut `1.0.0` deliberately when the collector is ready for it.

## Requirements

- A `RELEASE_PLEASE_TOKEN` repository secret holding a GitHub App installation
  token (or a PAT with `contents: write` and `pull-requests: write`). The
  default `GITHUB_TOKEN` will not work — see below.
- Branch protection on `main` must permit release-please to open and update its
  release PR.

### Why the default GITHUB_TOKEN is not enough

GitHub does not trigger workflows from events created with the built-in
`GITHUB_TOKEN`; it's a guard against recursive workflow runs. Since
release-please is what creates the release tag, a tag created with
`GITHUB_TOKEN` would not start `build-and-publish.yaml`, and no image would ever
be published. A GitHub App installation token (or PAT) is treated as a real
actor, so the tag push fires the build workflow normally.

## Version files

Two files carry the version and are updated together by release-please:

- `builder-config.yaml` (`dist.version`) — authoritative; this is what the
  collector build and the image tag use.
- `version.txt` — bookkeeping for release-please's `simple` strategy.

`build-and-publish.yaml` re-reads `dist.version` from `builder-config.yaml` and
fails the build if it disagrees with the tag, so the two cannot silently drift.

## Bumping the pinned OTel Collector version

`dist.version` (this project's release number) and the OTel
Collector/contrib version pinned throughout `builder-config.yaml` (e.g.
`v0.157.0`) are independent. Bumping one does not bump the other. To move
to a new upstream OTel release, update every `gomod:` line in
`builder-config.yaml` to the new version and land it with a conventional commit
(`feat:` is usual, since it changes what ships) — CI derives `telemetrygen`'s
version for the smoke test from the same file, so it stays in lockstep
automatically.
