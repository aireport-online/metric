# Metric

Houd je sportactiviteiten bij op je iPhone en Apple Watch, en deel je voortgang met vrienden via de website.

| Onderdeel | Map | Wat het doet |
| --- | --- | --- |
| iPhone-app | [`ios/Metric`](ios/Metric) | Workouts opnemen (GPS), importeren uit Apple Gezondheid, voortgang, vrienden, feed |
| Apple Watch-app | [`ios/MetricWatch`](ios/MetricWatch) | Workout opnemen met hartslag, energie en afstand; stuurt het resultaat naar de iPhone |
| Gedeelde Swift-code | [`ios/MetricCore`](ios/MetricCore) | Modellen, API-client en formattering (Swift package met tests) |
| Website + API | [`web`](web) | Online platform (feed, voortgang, vrienden, publieke profielen) en de API waar de app mee synct |
| API-documentatie | [`docs/api.md`](docs/api.md) | Het contract tussen app en server |

## Hoe het samenhangt

```
Apple Watch ──(WatchConnectivity + HealthKit)──▶ iPhone ──(HTTPS, /api/v1)──▶ Website + API ──▶ Postgres
                                                                                   ▲
                                                              vrienden bekijken je voortgang in de browser
```

- De iPhone-app werkt offline: activiteiten staan lokaal en worden gesynct zodra er verbinding is.
  Elke activiteit heeft een eigen `clientId`, dus dubbel uploaden levert nooit duplicaten op.
- Per activiteit kies je de zichtbaarheid: **alleen ik**, **vrienden** of **openbaar** (iedereen met de link).
- De website en de app gebruiken hetzelfde account.

## Website + API starten

Vereist: Node 22 en Postgres 16 (of Docker).

```bash
cd web
```

```bash
cp .env.example .env.local
```

```bash
npm install
```

```bash
npm run db:migrate
```

```bash
npm run db:seed
```

```bash
npm run dev
```

`db:seed` is optioneel en vult de database met demo-gebruikers en -activiteiten (alleen voor ontwikkeling).
De site draait daarna op <http://localhost:3000>.

Controles:

```bash
npm test
```

```bash
npm run typecheck && npm run lint && npm run build
```

De tests draaien tegen een echte Postgres-database (`metric_test`, instelbaar met `TEST_DATABASE_URL`).

### Online zetten

De iPhone-app heeft een server nodig die vanaf je telefoon bereikbaar is. Twee gangbare manieren:

1. **Docker** (eigen server/VPS): in de hoofdmap

   ```bash
   APP_URL=https://jouw-domein.nl POSTGRES_PASSWORD=kies-iets-sterks docker compose up --build -d
   ```

   De container voert bij het starten zelf de database-migraties uit. Zet er een reverse proxy met HTTPS voor.

2. **Een Node-host met beheerde Postgres** (bijv. Vercel, Render of Fly met Neon/Supabase):
   stel `DATABASE_URL` en `APP_URL` in en draai eenmalig `npm run db:migrate` tegen de productie-database.

Vul daarna het adres in bij de app (zie [`ios/README.md`](ios/README.md)).

## iPhone- en Watch-app bouwen

Vereist: een Mac met Xcode en [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd ios
```

```bash
brew install xcodegen && xcodegen generate
```

```bash
open Metric.xcodeproj
```

Stel in Xcode je team en bundle-ID in en kies je iPhone als doel. Alle stappen (HealthKit, server-adres, Watch)
staan in [`ios/README.md`](ios/README.md).

## Continuous integration

- `.github/workflows/web.yml`: typecheck, lint, tests (met Postgres) en build van de website.
- `.github/workflows/ios.yml`: tests van `MetricCore` en een build van de iPhone- en Watch-app op een macOS-runner.
