# Metric – website en API

Next.js-app met het online platform (feed, voortgang, vrienden, publieke profielen) en de API (`/api/v1`)
waar de iPhone-app mee synct. Opstarten, testen en online zetten staan in de [hoofd-README](../README.md);
het API-contract staat in [`docs/api.md`](../docs/api.md).

## Indeling

| Map | Inhoud |
| --- | --- |
| `src/server` | Servicelaag: accounts en sessies, activiteiten, vrienden, statistieken. Hier zit alle autorisatie. |
| `src/app/api/v1` | REST-routes voor de app; dunne laag boven de servicelaag |
| `src/app/(app)`, `src/app/(auth)` | Schermen van de website |
| `src/app/actions` | Server Actions voor de formulieren op de website |
| `src/components` | Interface-onderdelen, grafieken en de routekaart |
| `drizzle` | Database-migraties (gegenereerd met `npm run db:generate`) |
| `tests` | Integratietests van de API tegen een echte Postgres |

## Demo-gegevens

`npm run db:seed` maakt zes demo-accounts met twaalf weken aan activiteiten. Inloggen kan met
`sanne@metric.test` en wachtwoord `metric-demo`. Het script weigert te draaien met `NODE_ENV=production`.
