# kustomize through nora's GitHub releases proxy (3-day hold, maestra-io/issues-maestra#1649);
# sha256 = checksums.txt of the release. mode=0444: the stage runs as curl_user.
FROM packages.maestra.io/docker-hub/curlimages/curl:latest@sha256:3fb7e13e5d179a845c97d78204f3f1064d1907037f26a3ebf91710571151fd93 AS kustomize
# renovate: datasource=github-releases depName=kubernetes-sigs/kustomize
ARG KUSTOMIZE_VERSION=v5.7.1
ARG KUSTOMIZE_SHA256_AMD64=ea375e7372f9aa029129d4b2d16c66b7750b7f1213c4f66f910d981c895818d8
ARG KUSTOMIZE_SHA256_ARM64=4261a040217df3bd6896597c3986d1465925726e4f22a945304b5233a4dcdbda
ARG TARGETARCH
RUN --mount=type=secret,id=PRIVATE_PACKAGES_TOKEN,required=true,mode=0444 set -eu; \
  case "$TARGETARCH" in amd64) sha=$KUSTOMIZE_SHA256_AMD64 ;; arm64) sha=$KUSTOMIZE_SHA256_ARM64 ;; *) exit 1 ;; esac; \
  { printf 'user = "token:'; cat /run/secrets/PRIVATE_PACKAGES_TOKEN; printf '"\n'; } \
    | curl -fsSL --retry 2 -K - -o /tmp/kustomize.tgz \
      "https://packages.maestra.io/github/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz"; \
  echo "$sha  /tmp/kustomize.tgz" | sha256sum -c -; \
  tar xzf /tmp/kustomize.tgz -C /tmp kustomize

FROM packages.maestra.io/docker-hub/library/python:3.14-alpine@sha256:a18b20ad69e74df6cf6d2e1b1a260d7a1ecf5380fd83b310f83ba88c461cf894 AS base

# apk and pip packages through nora (packages.maestra.io, 3-day hold, maestra-io/issues-maestra#1649).
RUN --mount=type=secret,id=PRIVATE_PACKAGES_TOKEN,required=true --mount=type=bind,from=public.ecr.aws/g5f9s8a4/nora-apk:1.0.0@sha256:55df38687c301e6fefa230dc1c71a8841618214cc549ade71be740b25822a00e,target=/nora-apk \
    /nora-apk/nora-apk add --no-cache ca-certificates git

WORKDIR /app
COPY flux_local/ ./flux_local
COPY pyproject.toml .

RUN --mount=type=secret,id=PRIVATE_PACKAGES_TOKEN,env=NORA_TOKEN,required=true \
    PIP_INDEX_URL="https://token:${NORA_TOKEN}@packages.maestra.io/simple/" pip install -e .

COPY --from=packages.maestra.io/ghcr/fluxcd/flux-cli:v2.8.0@sha256:8e62461d83c13c0073c04cf695ba94a434e32a2636dc1a5a70c3e3ae6678dd08  /usr/local/bin/flux  /usr/local/bin/flux
COPY --from=packages.maestra.io/docker-hub/alpine/helm:4.1.1@sha256:b5c85b997d83e89d9e8ff9215a14b03864274143981af45eb3fe729cdf782c73     /usr/bin/helm        /usr/local/bin/helm

COPY --from=kustomize /tmp/kustomize /usr/local/bin/kustomize

USER 1001
ENTRYPOINT ["/usr/local/bin/flux-local"]
