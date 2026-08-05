# 02 – OCM-Komponente bauen

**Ziel:** Chart, Deployment-Werte und Images sind als eine OCM-Lieferung
beschrieben und liegen in einem CTF-Archiv vor.

```bash
source config/artifactory-lab.env
./scripts/build-ctf.sh
find dist/transport-archive -maxdepth 2 -type f | head
cat "dist/${COMPONENT_VERSION}-transport-archive.tgz.sha256"
```

Das Script erzeugt `dist/component-constructor.yaml`. Er enthält eine Resource
für das Helm-Chart, die Values-Vorlage und eine `ociImage`-Resource pro
gelocktem Image. Zunächst entsteht ein Descriptor-CTF; ein zweiter OCM-Transfer
kopiert dann sämtliche Images als lokale Blobs in das finale CTF. Nur dieses
selbständige finale Archiv ist die zu transportierende Einheit.

Vor der Freigabe sollte ein zweiter Mensch mindestens Version, Images und
Digest-Liste prüfen. Optional ergänzt ihr anschließend eine OCM-Signatur; der
öffentliche Schlüssel muss dann zusammen mit dem Paket in die Offline-Zone.

## Abnahme

`ocm get component-version ctf::dist/transport-archive//…` zeigt die erwartete
Komponente, und die SHA-256-Datei ist neben dem komprimierten Archiv vorhanden.
