# Metric voor iPhone en Apple Watch

Native SwiftUI-apps voor iOS 17+ en watchOS 10+. Zie [`docs/api.md`](../docs/api.md) voor de API waar de apps mee praten.

```
ios/
├── project.yml          XcodeGen-beschrijving van het Xcode-project
├── Config/              Metric.xcconfig: bundle-id, server-URL, team
├── MetricCore/          Swift package: API-client, modellen, formatters, statistiek (+ tests)
├── Shared/              Code die in beide apps zit (ring, HealthKit-mapping)
├── Metric/              iPhone-app
└── MetricWatch/         Watch-app
```

## Vereisten

- macOS met Xcode 16 of nieuwer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Een (gratis) Apple Developer-account om op je eigen iPhone en Watch te draaien

## Project openen

Het `.xcodeproj` wordt gegenereerd en staat niet in git:

```bash
brew install xcodegen
```

```bash
cd ios && xcodegen generate && open Metric.xcodeproj
```

Draai `xcodegen generate` opnieuw nadat je bestanden hebt toegevoegd of `project.yml` hebt gewijzigd.

## Instellen

Alles wat per persoon verschilt staat in `Config/Metric.xcconfig`:

| Instelling            | Betekenis |
| --------------------- | --------- |
| `METRIC_BUNDLE_ID`    | Bundle-id van de iPhone-app, bv. `nl.jouwnaam.metric`. De Watch-app wordt automatisch `<id>.watchkitapp`. |
| `METRIC_API_BASE_URL` | Adres van het Metric-platform. In een xcconfig schrijf je `//` als `/$()/`, dus `https:/$()/metric.voorbeeld.nl`. |
| `DEVELOPMENT_TEAM`    | Je Team-ID. Je kunt het team ook in Xcode kiezen onder *Signing & Capabilities* (voor beide targets). |

De server-URL is ook in de app te wijzigen: op het inlogscherm onder **Geavanceerd**.

Lokaal testen tegen `http://localhost:3000` werkt in de Simulator. Op een echt toestel vul je het
adres van je Mac in (`http:/$()/192.168.x.x:3000`) of de URL van je gehoste platform (https).

## HealthKit

Beide targets hebben de HealthKit-capability al via hun `.entitlements`-bestand. Bij automatische
signing maakt Xcode de bijbehorende App ID's zelf aan. In de app koppel je Gezondheid via de kaart
op **Vandaag** of via **Profiel**; daarna worden workouts (ook die uit de standaard Workout-app
op je Watch) automatisch geïmporteerd en gesynchroniseerd.

## Draaien

- **Simulator:** kies het scheme `Metric` en een iPhone-simulator. HealthKit werkt, maar er is geen echte sensordata.
- **iPhone + Watch:** kies het scheme `Metric` en je iPhone. De Watch-app wordt mee geïnstalleerd
  (anders: Watch-app op de iPhone → *Beschikbare apps*). Rechtstreeks op de Watch draaien kan met het scheme `MetricWatch`.

## Hoe het werkt

- **Offline-first:** activiteiten staan in SwiftData (`ActivityRecord`). `SyncService` uploadt wat
  klaarstaat (in batches, idempotent via `clientId`) en haalt daarna de servertoestand op.
- **Opnemen op de iPhone:** `WorkoutRecorder` (tijd + GPS). De workout wordt lokaal bewaard én in
  Gezondheid gezet, met de `clientId` als `HKMetadataKeyExternalUUID` zodat hij niet dubbel binnenkomt.
- **Opnemen op de Watch:** `WorkoutManager` gebruikt `HKWorkoutSession` + `HKLiveWorkoutBuilder`
  (hartslag, energie, afstand). Na afloop gaat een samenvatting via WatchConnectivity naar de iPhone;
  de route volgt zodra Gezondheid de workout naar de iPhone heeft gesynchroniseerd.
- **Watch zonder login:** de iPhone doet alle communicatie met de server en stuurt de weekvoortgang
  naar de Watch.

## Tests

```bash
cd ios/MetricCore && swift test
```

De GitHub Actions-workflow `.github/workflows/ios.yml` draait deze tests en bouwt beide apps voor de simulator.
