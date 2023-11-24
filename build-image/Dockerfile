# Build jsonnet
FROM alpine:3.18 AS jsonnet-builder
RUN apk add --no-cache git make g++
RUN git clone https://github.com/google/jsonnet && \
    git  -C jsonnet checkout v0.20.0 && \
    make -C jsonnet 2LDFLAGS=-static && \
    cp jsonnet/jsonnet /usr/bin && \
    cp jsonnet/jsonnetfmt /usr/bin

# Build jb
FROM alpine:3.18 AS jb-builder
ARG JSONNET_BUNDLER_VERSION=0.5.1
ARG JSONNET_BUNDLER_CHECKSUM="f5bccc94d28fbbe8ad1d46fd4f208619e45d368a5d7924f6335f4ecfa0605c85  /usr/bin/jb"
RUN apk add --no-cache curl
RUN curl -fSL -o "/usr/bin/jb" "https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/v${JSONNET_BUNDLER_VERSION}/jb-linux-amd64"
RUN echo "${JSONNET_BUNDLER_CHECKSUM}" | sha256sum -c || (printf "wanted: %s\n   got: %s\n" "${JSONNET_BUNDLER_CHECKSUM}" "$(sha256sum /usr/bin/jb)"; exit 1)
RUN chmod +x /usr/bin/jb

# Build tanka
FROM alpine:3.18 AS tk-builder
ARG TANKA_VERSION=0.26.0
ARG TANKA_CHECKSUM="089796ae2ce65390501b2c68ceca1ce99ff12787d5ae3b4823c825a07e6e22f4  /usr/bin/tk"
RUN apk add --no-cache curl
RUN curl -fSL -o "/usr/bin/tk" "https://github.com/grafana/tanka/releases/download/v${TANKA_VERSION}/tk-linux-amd64"
RUN echo "${TANKA_CHECKSUM}" | sha256sum -c || (printf "wanted: %s\n   got: %s\n" "${TANKA_CHECKSUM}" "$(sha256sum /usr/bin/tk)"; exit 1)
RUN chmod +x /usr/bin/tk

# Build mixtool
FROM golang:1.21-alpine AS mixtool-builder
RUN GO111MODULE=on go install github.com/monitoring-mixins/mixtool/cmd/mixtool@ae18e31161ea10545b9c1ac0d23c10122f2c12b5

FROM alpine:3.18
RUN apk add --no-cache git make libgcc libstdc++ zip findutils sed yq
COPY --from=jsonnet-builder /usr/bin/jsonnetfmt /usr/bin
COPY --from=jsonnet-builder /usr/bin/jsonnet /usr/bin
COPY --from=jb-builder /usr/bin/jb /usr/bin
COPY --from=tk-builder /usr/bin/tk /usr/bin
COPY --from=mixtool-builder /go/bin/mixtool /usr/bin

