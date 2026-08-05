# 00 – Liefergrenzen festlegen

**Ziel:** Es ist eindeutig, was die Zielanwendung benötigt und was die
Plattform bereits bereitstellt.

## Nicht Teil der OCM-Lieferung

- Kubernetes-Distribution und System-Pods,
- SCM, CI und deren Runner,
- die OCI Registry selbst,
- Ingress Controller, CNI, StorageClass und Identity Provider, sofern sie
  Plattform-Standards sind.

Diese Komponenten dürfen regulär aus dem Internet installiert und separat
betrieben werden. Sie müssen nur vor dem Ziel-Deployment verfügbar sein.

## Teil der OCM-Lieferung

- Ziel-Helm-Chart inklusive seiner Abhängigkeiten,
- alle Images des gerenderten Deployments, auch Init-Container, Jobs und Hooks,
- optionale CRDs, Konfigurations- und Migrationsartefakte sowie
- deployment-spezifische Values ohne Klartextsecrets.

Eine Anwendung ist erst „air-gapped lieferbar“, wenn der gerenderte Workload
keinen öffentlichen Image- oder Chart-Endpunkt mehr enthält.

## Abnahme

Es gibt einen Namen, eine Version, einen Ziel-Namespace und einen benannten
Registry-Endpunkt für die Anwendung. Platform-Team und Anwendungsteam stimmen
dem Umfang zu.
