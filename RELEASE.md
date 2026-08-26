# Releasing

Releases are automated with
[release-please](https://github.com/googleapis/release-please). Version numbers
come from commit messages, not from a manual bump. A release always ties
together three things that must match: `dist.version` in `builder-config.yaml`,
the git tag (`v<version>`), and the image tag pushed to GHCR.

The git tag itself stays plain semver, but the GitHub release *title* and one of
the image tags also carry the pinned OpenTelemetry Collector version — see
[Release naming](#release-naming).

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
   the GitHub release, then retitles that release to `v<version>/<otel-version>`.
5. The tag push triggers `build-and-publish.yaml`, which verifies the tag
   matches `dist.version`, builds the image, runs the smoke test, and pushes it
   to GHCR tagged `<version>`, `<version>-otel-<otel-version>`,
   `<version>-<sha>`, and `latest`.

Nothing is published to GHCR until a release tag exists. Pushes to `main` and
pull requests build the image and run the smoke test as a gate, but do not push.

## Release naming

Following
[open-telemetry/opentelemetry-collector](https://github.com/open-telemetry/opentelemetry-collector/releases),
a release surfaces two versions: this project's (builder config), and the OTel Collector version
it was built against.

| Surface | Example | Notes |
| --- | --- | --- |
| Git tag | `v0.2.0` | Plain semver; release-please's manifest depends on this |
| Release title | `v0.2.0/v0.159.0` | `<ours>/<otel>` |
| Image tag | `0.2.0-otel-v0.159.0` | `/` is illegal in a Docker tag, so `-otel-` is used |
| Image tags | `0.2.0`, `0.2.0-<sha>`, `latest` | Unchanged; `0.2.0` stays the one to pin |

The OTel version is never hand-written anywhere. `scripts/otel-version.sh`
extracts it from the `go.opentelemetry.io/collector/*` pins in
`builder-config.yaml` and is the single source for the release title, the image
tag, `BUILDER_VERSION` in the `Makefile`, and `telemetrygen` in the smoke test.
It fails loudly if those pins ever disagree with each other, so a partial
upstream bump breaks the build instead of shipping a mislabelled release.

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

The OTel version is deliberately *not* a version file — it is derived from the
`gomod:` pins by `scripts/otel-version.sh` rather than stored separately, so
there is nothing extra to keep in sync when Renovate bumps upstream.

## Bumping the pinned OTel Collector version

`dist.version` (this project's release number) and the OTel Collector/contrib
version pinned throughout `builder-config.yaml` (e.g. `v0.159.0`) are separate
numbers on separate schedules — bumping one does not renumber the other.

Renovate normally does the upstream bump: the `otel` group in `renovate.json`
moves every `go.opentelemetry.io/collector/**` and contrib `gomod:` line in a
single PR. Note that `renovate.json` sets `:semanticCommitTypeAll(feat)`, so
that PR lands as `feat(deps):` and therefore *does* cut a release — in practice
every OTel bump also ships a new `dist.version`.

To do it by hand, update every `gomod:` line to the new version and land it with
a conventional commit (`feat:` is usual, since it changes what ships). Either
way, everything downstream follows from those pins via
`scripts/otel-version.sh` — `telemetrygen`, `BUILDER_VERSION`, the image tag,
and the release title — and the build fails if the pins disagree.
