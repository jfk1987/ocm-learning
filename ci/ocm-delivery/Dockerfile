# Builder für den Woodpecker-Release-Job; nicht Teil der Zielanwendung.
FROM public.ecr.aws/docker/library/alpine:3.21

ARG HELM_VERSION=v3.17.3
ARG YQ_VERSION=v4.45.1
ARG OCM_VERSION=0.12.0
ARG TARGETARCH

RUN apk add --no-cache bash ca-certificates curl git openssl skopeo tar \
    && test -n "${TARGETARCH}" \
    && curl -fsSLo /tmp/helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    && tar -xzf /tmp/helm.tgz -C /tmp \
    && install -m 0755 "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm \
    && curl -fsSLo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH}" \
    && chmod 0755 /usr/local/bin/yq \
    && curl -fsSL https://ocm.software/install-cli.sh -o /tmp/install-ocm.sh \
    && OCM_VERSION="${OCM_VERSION}" bash /tmp/install-ocm.sh \
    && install -m 0755 /root/.local/bin/ocm /usr/local/bin/ocm \
    && rm -rf /tmp/*

WORKDIR /workspace
ENTRYPOINT ["/bin/bash"]
