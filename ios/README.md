# Metric voor iPhone en Apple Watch

Native SwiftUI-apps voor iOS 17+ en watchOS 10+. Zie [`docs/api.md`](../docs/api.md) voor de API waar de apps mee praten.

```
ios/
├── project.yml          XcodeGen-beschrijving van het Xcode-project
├── Config/              Metric.xcconfig: bundle-id, server-URL, team
├── MetricCore/          Swift package: API-client, modellen, formatters, statistiek (+ tests)
├── Shared/              Code die in beide apps zit (ring, HealthKit-mapping)
├── Metric/              iPhone-app
├── MetricWatch/         Watch-app
├── MetricUITests/       UI-test die de iPhone-app doorloopt (demovideo)
├── MetricWatchUITests/  UI-test die de Watch-app doorloopt (demovideo)
└── scripts/demo-video/  Hulpscripts van de workflow die de demovideo opneemt
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

## Huisstijl

De apps volgen de huisstijl in [`brand/`](../brand/README.md): altijd donker, tartan en volt als accenten, en de
atletiekbaan als voortgangsmotief.

- `Shared/Theme.swift` – kleuren, radii, beweging (duren, veren), lettertypen en de tint per sport.
- `Shared/TrackProgressView.swift` – de baan: banen die linksom vollopen vanaf de startstreep.
- `Shared/BrandComponents.swift` – knoppen, kaarten, optellende cijfers, binnenkomst van lijsten, live-stip en het
  aftelcijfer van het startschot.
- `Shared/Fonts/` – Barlow Condensed en Instrument Sans (OFL), geregistreerd via `UIAppFonts` in `project.yml`.
- `Metric/App/Appearance.swift` – navigatiebalk, tabbalk en segmentkiezers in de huisstijl.

Alle animaties houden rekening met "Verminder beweging": dan staat de eindtoestand er direct.

## Tests

```bash
cd ios/MetricCore && swift test
```

De GitHub Actions-workflow `.github/workflows/ios.yml` draait deze tests en bouwt beide apps voor de simulator.

## Demovideo (UI-tests)

`MetricUITests` en `MetricWatchUITests` lopen de apps in de simulator door: inloggen, de week, een activiteit
met route, de feed met kudos, de ranglijst, een workout opnemen en het profiel; op de Watch een workout van
start tot samenvatting. De workflow `.github/workflows/demo-video.yml` (handmatig te starten) zet een lokale
server met demo-gegevens klaar, neemt het scherm op terwijl de tests draaien en levert de video's af als
artifact en op de branch `ci/demo-video`. De hulpscripts staan in `scripts/demo-video/`; tijdens de iPhone-test
laat `simctl location` de simulator een rondje door het Vondelpark lopen, zodat de opname afstand en tempo toont.

De tests starten de apps met het argument `-UITestDemo` (zie `Shared/DemoMode.swift`). Daarmee begint de
iPhone-app leeg op het inlogscherm, blijft Gezondheid buiten beeld en gebruikt de opname een eenvoudige
locatiesessie; de Watch-app draait de workout op een timer met voorbeeldwaarden. Zonder dat argument doet de
demo-modus niets.

Lokaal draaien kan ook: start de website met de demo-gegevens (`npm run db:seed`) op `http://localhost:3000`
en voer het scheme `MetricUITests` of `MetricWatchUITests` uit op een simulator.
