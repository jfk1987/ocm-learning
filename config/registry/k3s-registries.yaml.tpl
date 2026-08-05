# Datei ist Node-sensitiv: Nutzername und Passwort nur lokal ersetzen,
# Berechtigungen 0600 setzen. Das CA-Zertifikat wird separat ausgerollt.
configs:
  registry.airgap.example:5000:
    auth:
      username: REPLACE_WITH_REGISTRY_PULL_USER
      password: REPLACE_WITH_REGISTRY_PULL_PASSWORD
    tls:
      ca_file: /etc/rancher/k3s/certs/zot-ca.crt
