# flyr-otel-collector

Custom OpenTelemetry Collector distribution, built with the
[OpenTelemetry Collector Builder (OCB)](https://github.com/open-telemetry/opentelemetry-collector/tree/main/cmd/builder)
from `builder-config.yaml`. Includes FLYR's
[`datadogtagsprocessor`](https://github.com/FLYR-Open-Source/datadogtagsprocessor),
which moves or merges resource/span/log attributes into the `ddtags`
attribute the Datadog exporter reads.

Intended to run as the collector image for an `OpenTelemetryCollector`
custom resource managed by the
[OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator).

## Components

All components are pinned to the OTel Collector/contrib release declared at
the top of `builder-config.yaml` (currently `v0.157.0`), plus:

- `datadog_tags` — `github.com/FLYR-Open-Source/datadogtagsprocessor`

See `builder-config.yaml` for the full receiver/processor/exporter/
extension/connector list.

## Building locally

```bash
make build-builder
```

Installs `ocb` at the pinned version and builds the collector binary to
`_build/flyr-otel-collector`.

## Building the Docker image

```bash
docker build -t flyr-otel-collector:local .
```

Multi-stage build: `golang:1.26-alpine` runs `make build-builder`, then the
binary is copied into a `gcr.io/distroless/base-debian12:nonroot` runtime
image. The image has no baked-in config and no default `CMD` — a `--config`
path must always be passed at run time.

### Running it standalone (smoke testing)

`config.yaml` in this repo is a smoke-test config only — it wires the
`resource`, `attributes`, `transform`, and `datadog_tags` processors
together with `file` exporters so the smoke test can assert on the
resulting `ddtags` attribute as structured OTLP JSON. It is not meant to
be the production pipeline; that's supplied by the `OpenTelemetryCollector`
CR's `spec.config` when running under the Operator.

Run the whole thing (build, start the collector via `docker compose`, send
test traces/logs with
[`telemetrygen`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/telemetrygen),
and assert `ddtags` in the output) with:

```bash
make smoke-test
```

or directly:

```bash
./scripts/smoke-test.sh
```

This is the same script the CI workflow runs, using
`docker-compose.smoke-test.yaml`. Output files land in
`.smoke-test-output/traces.json` and `.smoke-test-output/logs.json` for
inspection.

## Running under the OpenTelemetry Operator

Point an `OpenTelemetryCollector` CR at a published image and supply your
real pipeline config via `spec.config` — the Operator mounts its own
generated config and passes `--config`, ignoring anything baked into the
image:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: flyr-otel-collector
spec:
  image: ghcr.io/flyr-open-source/flyr-otel-collector:<version>
  config:
    receivers: ...
    processors: ...
    exporters: ...
    service:
      pipelines: ...
```

## CI/CD

`.github/workflows/build-and-publish.yaml` runs on every PR, push to the
default branch, and `v*.*.*` tag:

1. Builds the Docker image once, tagged with `dist.version`,
   `dist.version-<sha>`, and `latest`, and loads it into the local Docker
   daemon (no push yet).
2. Runs `scripts/smoke-test.sh` against that exact image: starts it with
   `config.yaml` via `docker-compose.smoke-test.yaml`, sends test
   traces/logs via `telemetrygen` (pinned to the same OTel version as
   `builder-config.yaml`), and asserts `ddtags` was populated correctly in
   both the trace and log output.
3. On anything other than a PR, pushes the already-built image (no
   rebuild) to GHCR under the same three tags — the exact artifact that
   was smoke-tested.
4. On a `v*.*.*` tag push, verifies the tag matches `dist.version` in
   `builder-config.yaml` before building — a mismatch fails the job.

## Releasing

See [RELEASE.md](./RELEASE.md).
