# 05 – Air-gap-Nachweis führen

**Ziel:** Nicht nur der erfolgreiche Start, sondern die fehlende externe
Abhängigkeit ist überprüft.

```bash
kubectl get pods -n target-application \
  -o jsonpath='{range .items[*]}{range .spec.initContainers[*]}{.image}{"\n"}{end}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' \
  | sort -u
kubectl get events -n target-application --sort-by=.lastTimestamp
```

Jede ausgegebene Image-Referenz muss mit `${LOCAL_REGISTRY}/` beginnen. Prüfe
zusätzlich die Plattform-Telemetrie oder Firewall-Logs: Während Installation,
Pod-Start und einem kontrollierten Pod-Neustart darf kein Egress zu einer
öffentlichen Registry stattfinden.

Als Negativtest ersetze in einem nicht-produktiven Namespace eine Image-
Referenz durch den originalen Upstream-Namen. Der Pull muss scheitern. Dieser
Test beweist, dass der Erfolg nicht von einem transparenten Internet-Proxy
abhängt.

## Abnahme

Positiv- und Negativtest sind dokumentiert. Descriptor, Lockfile, CTF-Version
und die tatsächlich gestarteten Image-Digests stimmen überein.
