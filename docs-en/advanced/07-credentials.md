# OCM 07 – Explore credential resolution in practice

**Goal:** A second registry rejects anonymous access. Only a matching OCM
Consumer Identity enables the transfer.

This lab is independent of the air-gapped target cluster and runs on the host.

## 1. Start an authenticated lab registry

```bash
./scripts/create-auth-registry.sh
. .lab/auth-registry/credentials.env

curl --show-error http://localhost:5001/v2/
curl --fail --show-error \
  --user "$AUTH_REGISTRY_USERNAME:$AUTH_REGISTRY_PASSWORD" \
  http://localhost:5001/v2/
```

The first call returns the expected HTTP 401; the second returns HTTP 200. The
registry deliberately uses HTTP only and binds only to `127.0.0.1`.

## 2. Create the OCM configuration

```bash
cat > .lab/auth-registry/ocmconfig.yaml <<EOF
type: generic.config.ocm.software/v1
configurations:
  - type: credentials.config.ocm.software
    consumers:
      - identity:
          type: OCIRegistry
          hostname: localhost
          scheme: http
          port: "5001"
          path: protected
        credentials:
          - type: OCICredentials/v1
            username: ${AUTH_REGISTRY_USERNAME}
            password: ${AUTH_REGISTRY_PASSWORD}
EOF
chmod 600 .lab/auth-registry/ocmconfig.yaml
```

The identity is not a login command. It describes **when** OCM selects which
credentials. The scheme, host, port, and path must match the request.

## 3. Compare a missing and a matching identity

```bash
export TARGET_APP_WORKDIR="$PWD/.lab/workspaces/target-application"
export DELIVERY_DIR="$TARGET_APP_WORKDIR/delivery/target-application"
export COMPONENT_NAME="$(yq -r '.component.name' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export COMPONENT_VERSION="$(yq -r '.component.version' "$TARGET_APP_WORKDIR/config/application.lock.yaml")"
export SOURCE_CTF="$DELIVERY_DIR/transport-archive-$COMPONENT_VERSION"

printf '%s\n' 'type: generic.config.ocm.software/v1' \
  > .lab/auth-registry/empty-config.yaml
if OCM_CONFIG="$PWD/.lab/auth-registry/empty-config.yaml" \
  ocm transfer component-version \
  "ctf::$SOURCE_CTF//$COMPONENT_NAME:$COMPONENT_VERSION" \
  'oci::http://localhost:5001/protected' \
  --recursive --copy-resources --upload-as ociArtifact; then
  echo 'ERROR: anonymous transfer succeeded.' >&2
  false
else
  echo 'Expected 401 without credentials.'
fi

OCM_CONFIG="$PWD/.lab/auth-registry/ocmconfig.yaml" \
  ocm transfer component-version \
  "ctf::$SOURCE_CTF//$COMPONENT_NAME:$COMPONENT_VERSION" \
  'oci::http://localhost:5001/protected' \
  --recursive --copy-resources --upload-as ociArtifact
```

Then deliberately test a non-matching path, `other`. The identity with
`path: protected` must not provide credentials there. In OCM, `*` matches
exactly one path segment, not an arbitrary number of `/`-separated segments.

## 4. Put alternative credential sources in context

OCM can also consume credentials from Docker config, Kubernetes Secrets, or
external credential plugins. Selection by identity remains the same. In CI,
the OCM config document belongs in a Woodpecker Secret, not in the Git
repository.

## Acceptance

Without configuration, 401 appears; with the exact Consumer Identity, the
Component Version is readable under `protected`; and the config file has mode
600.

Next: [OCM 08 – Component References](08-component-references.md).
