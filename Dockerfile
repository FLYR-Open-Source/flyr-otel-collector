FROM gcr.io/distroless/base-debian12

COPY _build/flyr-otel-collector /flyr-otel-collector

ENTRYPOINT ["/flyr-otel-collector"]

EXPOSE 4317 4318
