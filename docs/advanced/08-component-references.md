# OCM 08 – Ein Produkt aus mehreren Komponenten modellieren

**Ziel:** Du baust Backend und Produkt gemeinsam und navigierst vom Produkt
über eine Component Reference zum Backend.

## 1. Beispiel lesen

```bash
yq '.' examples/ocm/multi-component/component-constructor.yaml
```

Der Constructor enthält zwei Component Versions:

- `example.org/ocm-learning/backend:1.0.0` mit einer Config-Resource;
- `example.org/ocm-learning/product:1.0.0` mit eigener Resource und der
  Component Reference `name=backend`.

Eine Component Reference kopiert die Kind-Komponente nicht in den Descriptor.
Sie deklariert eine versionierte Abhängigkeit. `extraIdentity.environment=lab`
zeigt zusätzlich eine zusammengesetzte Resource Identity.

## 2. Beide Versionen bauen

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

## 3. Rekursiven Transfer beobachten

```bash
ocm transfer component-version \
  "ctf::$MULTI_CTF//example.org/ocm-learning/product:1.0.0" \
  'oci::http://localhost:5000/ocm-multi' \
  --recursive --copy-resources --upload-as ociArtifact

ocm get component-version \
  'oci::http://localhost:5000/ocm-multi//example.org/ocm-learning/backend:1.0.0'
```

Ohne `--recursive` reist nur die Root Component Version. Mit der Option folgt
OCM den References und überträgt den Backend-Descriptor samt Resource.

## 4. Versionierungsentscheidung

Ändere testweise die Backend-Version auf `1.1.0`, aber nicht die Reference
im Produkt. Der Constructor kann beide Objekte bauen; das Produkt referenziert
weiterhin exakt 1.0.0. Erst eine neue Produktversion sollte die neue Backend-
Version aufnehmen. So bleibt eine Produktversion reproduzierbar.

## Abnahme

Beide Komponenten sind in der Zielregistry abfragbar, der Produkt-Descriptor
enthält die Reference `backend`, und du kannst erklären, warum rekursiver
Transfer nicht dasselbe wie `--copy-resources` ist.

Weiter mit [OCM 09 – Resolver](09-resolvers.md).
