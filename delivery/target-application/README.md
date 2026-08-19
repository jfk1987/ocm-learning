# Lieferarbeitsverzeichnis der Zielanwendung

This directory is versioned together with the lockfile. Before a release, it
contains at least:

- `target-application-chart.tgz` – the pinned Helm chart, packaged together
  with its dependencies;
- `values-airgap.yaml` – approved target values without plaintext secrets;
- optional directories for CRDs, migration manifests, or configuration files
  listed as `additionalResources` in the lockfile.

The CI release only creates the following temporary files here:
`component-constructor-<version>.yaml` and
`transport-archive-<version>/`. These files are ignored and must not be
committed.
