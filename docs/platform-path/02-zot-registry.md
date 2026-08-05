# 02 – Zot als Bootstrap-Registry

**Ziel:** Die Offline-Zone besitzt vor dem Clusterstart eine TLS-geschützte,
persistente OCI Registry.

## Aufgabe

Entnimm `zot` und `zot-config.json` aus der importierten Bootstrap-OCM-
Komponente. Lege auf dem Registry-Host an:

```text
/etc/zot/config.json       Konfiguration ohne Klartextpasswort
/etc/zot/tls/              Zertifikat und Schlüssel der internen CA
/etc/zot/htpasswd          lokale Nutzerdatei, Berechtigung 0600
/var/lib/zot/              persistenter Registry-Speicher
```

Die Vorlage unter [config/registry/zot-config.json.tpl](../../config/registry/zot-config.json.tpl)
enthält lokale Speicherung, TLS und Basis-Authentisierung. Erzeuge `htpasswd`
und Schlüssel ausschließlich in der Offline-Zone. Sie gehören nie in CTF oder
Git.

Installiere anschließend die Binary als `/usr/local/bin/zot`, kopiere die
[systemd-Vorlage](../../config/registry/zot.service.tpl) nach
`/etc/systemd/system/zot.service` und starte sie:

```bash
zot verify /etc/zot/config.json
systemctl daemon-reload
systemctl enable --now zot
curl --cacert /etc/zot/tls/ca.crt --user '<registry-user>:<password>' \
  https://registry.airgap.example:5000/v2/
```

Der nichtprivilegierte Nutzer `zot` muss Besitzer von `/var/lib/zot` sein. Die
Einheit erlaubt Schreibzugriffe ausschließlich auf diesen Pfad.

## Abnahme

`/v2/` antwortet per TLS, der Dienst übersteht einen Neustart, und ein
anonymer Push wird abgelehnt.
