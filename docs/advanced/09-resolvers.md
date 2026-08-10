# OCM 09 – Referenzen über getrennte Repositories auflösen

**Ziel:** Produkt und Backend liegen in getrennten CTFs. Ein deterministischer
Resolver findet beim rekursiven Transfer die referenzierte Backend-Version.

## 1. Das gemeinsame Build-Ergebnis aufteilen

OCM 08 hat beide Component Versions in `.lab/multi-component-ctf` erzeugt.
Kopiere nun jede Version bewusst in ein eigenes Repository:

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

Der zweite Befehl verwendet absichtlich kein `--recursive`. Deshalb kennt der
Produkt-Descriptor seine Backend-Reference, aber sein CTF enthält die
Backend-Version nicht:

```bash
if ocm get component-version \
  'ctf::.lab/product-only-ctf//example.org/ocm-learning/backend:1.0.0'; then
  echo 'FEHLER: Backend ist unerwartet im Produkt-CTF.' >&2
  false
else
  echo 'Erwartet: Backend fehlt im Produkt-CTF.'
fi
```

## 2. Resolver-Konfiguration erzeugen

Die Vorlage verwendet drei Auswahlmerkmale: Repository-Spezifikation,
Component-Namenspattern und Versionsconstraint.

```bash
export BACKEND_CTF="$PWD/.lab/backend-only-ctf"
cp examples/ocm/resolver-config.yaml .lab/resolver-config.yaml
BACKEND_CTF="$BACKEND_CTF" yq -i \
  '.configurations[0].resolvers[0].repository.filePath = strenv(BACKEND_CTF)' \
  .lab/resolver-config.yaml
yq '.' .lab/resolver-config.yaml
```

Der Pfad ist absolut, damit die Auflösung nicht vom Aufrufverzeichnis abhängt.
`example.org/ocm-learning/*` begrenzt den Namensraum, `>=1.0.0 <2.0.0` die
akzeptierten Versionen.

## 3. Rekursiven Transfer mit Resolver ausführen

```bash
ocm transfer component-version \
  'ctf::.lab/product-only-ctf//example.org/ocm-learning/product:1.0.0' \
  'ctf::.lab/resolved-product-ctf' \
  --recursive --copy-resources --upload-as localBlob \
  --config .lab/resolver-config.yaml

ocm get component-version \
  'ctf::.lab/resolved-product-ctf//example.org/ocm-learning/backend:1.0.0'
```

Jetzt enthält das Ziel wieder beide Versionen. Die Reference modelliert die
Abhängigkeit, `--recursive` folgt ihr, und der Resolver bestimmt, in welchem
Repository der fehlende Descriptor gefunden wird.

## 4. Determinismus als Negativtest

Ändere in einer Kopie `componentNamePattern` auf `example.org/other/*` oder
die Constraint auf `>=2.0.0`. Wiederhole den Transfer in ein neues, leeres
Ziel-CTF. Er muss scheitern, weil der Resolver das Backend 1.0.0 nicht mehr
beansprucht. Eine unbeschränkte globale Fallback-Liste wird dadurch vermieden.

## Abnahme

Das Produkt-CTF enthält allein kein Backend. Erst der rekursive Transfer mit
passendem Resolver erzeugt ein Ziel-CTF mit beiden Component Versions.

Weiter mit [OCM 10 – Kubernetes Controller](10-controller.md).
