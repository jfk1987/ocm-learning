{
  "distSpecVersion": "1.1.0",
  "storage": {
    "rootDirectory": "/var/lib/zot",
    "dedupe": true,
    "gc": true,
    "gcDelay": "1h",
    "gcInterval": "24h"
  },
  "http": {
    "address": "0.0.0.0",
    "port": "5000",
    "realm": "airgap-registry",
    "compat": ["docker2s2"],
    "tls": {
      "cert": "/etc/zot/tls/tls.crt",
      "key": "/etc/zot/tls/tls.key"
    },
    "auth": {
      "htpasswd": {
        "path": "/etc/zot/htpasswd"
      },
      "failDelay": 5
    }
  }
}
