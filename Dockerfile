FROM alpine:3.24 AS certs
RUN apk --update add ca-certificates

FROM gcr.io/distroless/base:latest

ARG USER_UID=10001
USER ${USER_UID}

COPY ./config.yaml /otelcol/collector-config.yaml
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --chmod=755 _build/flyr-otel-collector /flyr-otel-collector

ENTRYPOINT ["/flyr-otel-collector"]
CMD ["--config", "/otelcol/collector-config.yaml"]

EXPOSE 4317 4318 12001