# OCM 09 – Resolve references across separate repositories

**Goal:** The product and backend are in separate CTFs. A deterministic
resolver finds the referenced backend version during recursive transfer.

## 1. Split the shared build result

OCM 08 created both Component Versions in `.lab/multi-component-ctf`. Now copy
each version deliberately into its own repository:

```bash
rm -rf .lab/product-only-ctf .lab/backend-only-ctf .lab/resolved-product-ctf

ocm transfer component-version \
  'ctf::.lab/multi-component-ctf//example.org/ocm-learning/backend:1.0.0' \
  'ctf::.lab/backend-only-ctf' \
  --copy-resources --upload-as localBlob

ocm transfer component-version \
  'ctf::.lab/multi-component-ctf//example.org/ocm-learning/product:1.0.0' \
  'ctf::.lab/product-only-ctf' \
  --copy-resources --upload-as localBlob
```

The second command deliberately does not use `--recursive`. Therefore the
product descriptor knows its backend Reference, but its CTF does not contain
the backend version:

```bash
if ocm get component-version \
  'ctf::.lab/product-only-ctf//example.org/ocm-learning/backend:1.0.0'; then
  echo 'ERROR: backend unexpectedly exists in the product CTF.' >&2
  false
else
  echo 'Expected: backend is missing from the product CTF.'
fi
```

## 2. Create the resolver configuration

The template uses three selection criteria: repository specification, component
name pattern, and version constraint.

```bash
export BACKEND_CTF="$PWD/.lab/backend-only-ctf"
cp examples/ocm/resolver-config.yaml .lab/resolver-config.yaml
BACKEND_CTF="$BACKEND_CTF" yq -i \
  '.configurations[0].resolvers[0].repository.filePath = strenv(BACKEND_CTF)' \
  .lab/resolver-config.yaml
yq '.' .lab/resolver-config.yaml
```

The path is absolute so resolution does not depend on the calling directory.
`example.org/ocm-learning/*` limits the namespace; `>=1.0.0 <2.0.0` limits
accepted versions.

## 3. Run recursive transfer with the resolver

```bash
ocm transfer component-version \
  'ctf::.lab/product-only-ctf//example.org/ocm-learning/product:1.0.0' \
  'ctf::.lab/resolved-product-ctf' \
  --recursive --copy-resources --upload-as localBlob \
  --config .lab/resolver-config.yaml

ocm get component-version \
  'ctf::.lab/resolved-product-ctf//example.org/ocm-learning/backend:1.0.0'
```

The target now contains both versions again. The Reference models the
dependency, `--recursive` follows it, and the resolver determines which
repository contains the missing descriptor.

## 4. Use determinism as a negative test

In a copy, change `componentNamePattern` to `example.org/other/*` or the
constraint to `>=2.0.0`. Repeat the transfer into a new, empty target CTF. It
must fail because the resolver no longer claims backend 1.0.0. This avoids an
unbounded global fallback list.

## Acceptance

The product CTF alone contains no backend. Only recursive transfer with a
matching resolver creates a target CTF with both Component Versions.

Next: [OCM 10 – Kubernetes controller](10-controller.md).
