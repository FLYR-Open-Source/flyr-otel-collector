# flyr-otel-collector

Custom OpenTelemetry Collector distribution, built with the
[OpenTelemetry Collector Builder (OCB)](https://github.com/open-telemetry/opentelemetry-collector/tree/main/cmd/builder)
from `builder-config.yaml`.

Intended to run as the collector image for an `OpenTelemetryCollector`
custom resource managed by the
[OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator).

The image is published to
[`ghcr.io/flyr-open-source/flyr-otel-collector`](https://github.com/FLYR-Open-Source/flyr-otel-collector/pkgs/container/flyr-otel-collector).

## Components

All components below are pinned to the OTel Collector/contrib release
declared at the top of `builder-config.yaml`, except
FLYR's own processor.

**Receivers:** `otlp`, `filelog`, `hostmetrics`, `k8scluster`,
`prometheus`, `cloudflare`, `googlecloudspanner`, `httpcheck`, `tcpcheck`,
`sqlserver`, `sqlquery`

**Processors:** `batch`, `memory_limiter`, `k8sattributes`,
`resourcedetection`, `attributes`, `resource`, `filter`, `transform`,
`metricstransform`, `cumulativetodelta`, `cardinalityguardian`

**Exporters:** `otlp`, `debug`, `file`, `loadbalancing`, `datadog`

**Extensions:** `datadog`, `cgroupruntime`

**Connectors:** `datadog`, `signaltometrics`, `routing`

**FLYR custom:**

- `datadog_tags` —
  [`datadogtagsprocessor`](https://github.com/FLYR-Open-Source/datadogtagsprocessor),
  which moves or copies resource/span/log attributes into the `ddtags`
  attribute the Datadog exporter reads.

See `builder-config.yaml` for exact module paths and pinned versions.

## Building locally

```bash
make build
```

Installs `ocb` at the pinned version into `.tools/` and builds the collector
binary to `_build/flyr-otel-collector`.

The binary is cross-compiled for the container platform (`linux/$(go env
GOARCH)` by default) rather than your host, so it can be copied straight into
the image. Override with `TARGET_OS`/`TARGET_ARCH`:

```bash
make build TARGET_ARCH=amd64
```

## Building the Docker image

```bash
make image
```

Compiles the binary as above, then copies it into a
`gcr.io/distroless/base-debian12:nonroot` runtime image. The Dockerfile is
packaging only — it does not compile anything, which is what lets the Go build
cache persist between builds instead of being discarded with the BuildKit
instance. `docker build` on its own therefore requires
`_build/flyr-otel-collector` to already exist.

The image has no baked-in config and no default `CMD` — a `--config` path must
always be passed at run time.

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

## Verifying the images signatures

> [!NOTE]
> To verify a signed artifact or blob, first [install Cosign](https://docs.sigstore.dev/cosign/system_config/installation/), then follow the instructions below.

We are signing the image using [sigstore cosign](https://github.com/sigstore/cosign) tool and to verify the signatures you can run the following command:

```console
$ cosign verify \
  --certificate-identity=https://github.com/flyr-open-source/flyr-otel-collector/.github/workflows/build-and-publish.yaml.yaml@refs/tags/<RELEASE_TAG> \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  <OTEL_COLLECTOR_IMAGE>
```

where:

- `<RELEASE_TAG>`: is the release that you want to validate
- `<OTEL_COLLECTOR_IMAGE>`: is the image that you want to check

Example:

TBD:

```console

```

> [!NOTE]
> We started signing the images with release `v0.95.0`

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
