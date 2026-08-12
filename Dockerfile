# syntax=docker/dockerfile:1

FROM golang:1.26-alpine AS builder

RUN apk add --no-cache make

WORKDIR /build

COPY builder-config.yaml Makefile ./
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/root/go/pkg/mod \
    make build-builder

FROM gcr.io/distroless/base-debian12:nonroot

COPY --from=builder /build/_build/flyr-otel-collector /flyr-otel-collector

USER nonroot:nonroot

ENTRYPOINT ["/flyr-otel-collector"]

EXPOSE 4317 4318
