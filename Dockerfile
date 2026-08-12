FROM gcr.io/distroless/base-debian12:nonroot

COPY _build/flyr-otel-collector /flyr-otel-collector

USER nonroot:nonroot

ENTRYPOINT ["/flyr-otel-collector"]

EXPOSE 4317 4318
