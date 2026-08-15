# OCM 08 – Model a product made of multiple components

**Goal:** You build the backend and product together and navigate from the
product to the backend through a Component Reference.

## 1. Read the example

```bash
yq '.' examples/ocm/multi-component/component-constructor.yaml
```

The constructor contains two Component Versions:

- `example.org/ocm-learning/backend:1.0.0` with a config Resource;
- `example.org/ocm-learning/product:1.0.0` with its own Resource and the
  `name=backend` Component Reference.

A Component Reference does not copy the child component into the descriptor.
It declares a versioned dependency. `extraIdentity.environment=lab` also
shows a composite Resource identity.

## 2. Build both versions

```bash
export MULTI_CTF="$PWD/.lab/multi-component-ctf"
rm -rf "$MULTI_CTF"
(cd examples/ocm/multi-component && ocm add component-version \
  --repository "ctf::$MULTI_CTF" \
  --constructor component-constructor.yaml)

ocm get component-version \
  "ctf::$MULTI_CTF//example.org/ocm-learning/product:1.0.0" \
  -o yaml > .lab/product-component.yaml
yq '.[0].component.componentReferences' .lab/product-component.yaml
```

## 3. Observe recursive transfer

```bash
ocm transfer component-version \
  "ctf::$MULTI_CTF//example.org/ocm-learning/product:1.0.0" \
  'oci::http://localhost:5000/ocm-multi' \
  --recursive --copy-resources --upload-as ociArtifact

ocm get component-version \
  'oci::http://localhost:5000/ocm-multi//example.org/ocm-learning/backend:1.0.0'
```

Without `--recursive`, only the root Component Version travels. With the
option, OCM follows the References and transfers the backend descriptor and
Resource as well.

## 4. Make a versioning decision

As a test, change the backend version to `1.1.0`, but not the Reference in the
product. The constructor can build both objects; the product still refers to
exactly 1.0.0. Only a new product version should include the new backend
version. This keeps a product version reproducible.

## Acceptance

Both components can be queried in the target registry, the product descriptor
contains the `backend` Reference, and you can explain why recursive transfer is
not the same as `--copy-resources`.

Next: [OCM 09 – Resolver](09-resolvers.md).
