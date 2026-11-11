# Metric API (v1)

De iPhone-app, de Watch-app (via de iPhone) en de website praten allemaal met dezelfde API.

- Basis-URL: `<host>/api/v1`
- Formaat: JSON (`Content-Type: application/json`)
- Datums: ISO 8601 in UTC (`2026-11-11T07:30:00.000Z`)
- Eenheden: afstand in **meters**, duur in **seconden**, energie in **kcal**, hartslag in **bpm**
- ID's: UUID-strings

## Authenticatie

De app stuurt `Authorization: Bearer <token>`. De website gebruikt een `metric_session` cookie
(httpOnly). Beide verwijzen naar dezelfde sessietabel.

Fouten hebben altijd deze vorm:

```json
{ "error": { "code": "invalid_credentials", "message": "E-mailadres of wachtwoord klopt niet." } }
```

| Status | `code`                                   |
| ------ | ---------------------------------------- |
| 400    | `invalid_request` (validatie)            |
| 401    | `unauthorized`, `invalid_credentials`    |
| 403    | `forbidden`                              |
| 404    | `not_found`                              |
| 409    | `email_taken`, `username_taken`, `conflict` |
| 429    | `rate_limited`                           |

## Objecten

### UserSummary

```json
{ "id": "…", "username": "wietse", "displayName": "Wietse" }
```

### Me (UserSummary +)

```json
{
  "id": "…", "username": "wietse", "displayName": "Wietse",
  "email": "…", "bio": "", "weeklyGoalMinutes": 150,
  "defaultVisibility": "friends", "createdAt": "…"
}
```

### Activity

```json
{
  "id": "…",
  "clientId": "…",
  "user": { "id": "…", "username": "wietse", "displayName": "Wietse" },
  "type": "run",
  "title": "Ochtendrun",
  "notes": "",
  "startedAt": "2026-11-11T07:30:00.000Z",
  "durationSeconds": 1820,
  "distanceMeters": 5230.4,
  "elevationGainMeters": 31,
  "activeEnergyKcal": 412,
  "avgHeartRate": 152,
  "maxHeartRate": 178,
  "source": "watch",
  "visibility": "friends",
  "hasRoute": true,
  "route": [[52.3702, 4.8952], [52.3705, 4.8961]],
  "kudosCount": 3,
  "commentCount": 1,
  "hasKudoed": false,
  "createdAt": "…"
}
```

- `type`: `run`, `walk`, `hike`, `ride`, `swim`, `strength`, `hiit`, `yoga`, `rowing`, `football`, `tennis`, `other`
- `source`: `iphone`, `watch`, `health`, `web`
- `visibility`: `private` (alleen ik), `friends` (vrienden), `public` (iedereen met de link)
- `distanceMeters`, `elevationGainMeters`, `activeEnergyKcal`, `avgHeartRate`, `maxHeartRate` kunnen `null` zijn
- `route` (lijst van `[lat, lon]`) zit alleen in het detail-antwoord (`GET /activities/:id`); in lijsten alleen `hasRoute`
- `clientId` is de UUID die het apparaat zelf kiest. Uploaden met een bestaande `clientId` werkt de activiteit bij
  in plaats van een duplicaat te maken (idempotente sync).

### Comment

```json
{ "id": "…", "user": { …UserSummary }, "body": "Lekker bezig!", "createdAt": "…" }
```

## Endpoints

### Account

| Methode | Pad              | Body                                              | Antwoord            |
| ------- | ---------------- | ------------------------------------------------- | ------------------- |
| POST    | `/auth/register` | `{ email, password, username, displayName }`      | `201 { token, user: Me }` |
| POST    | `/auth/login`    | `{ email, password }`                             | `200 { token, user: Me }` |
| POST    | `/auth/logout`   | –                                                 | `204`               |
| GET     | `/me`            | –                                                 | `{ user: Me }`      |
| PATCH   | `/me`            | `{ displayName?, bio?, weeklyGoalMinutes?, defaultVisibility? }` | `{ user: Me }` |
| DELETE  | `/me`            | `{ password }`                                    | `204` (verwijdert account en alle data) |

- `username`: 3–20 tekens, `a-z`, `0-9`, `_` (wordt naar kleine letters omgezet)
- `password`: minimaal 8 tekens

### Activiteiten

| Methode | Pad                       | Body / query                       | Antwoord |
| ------- | ------------------------- | ---------------------------------- | -------- |
| GET     | `/activities`             | `?before=<iso>&limit=<1-100>`      | `{ activities: Activity[], nextCursor: string \| null }` |
| POST    | `/activities`             | `ActivityInput`                    | `201 { activity }` (of `200` bij update via `clientId`) |
| POST    | `/activities/batch`       | `{ activities: ActivityInput[] }` (max 50) | `{ activities: Activity[] }` |
| GET     | `/activities/:id`         | –                                  | `{ activity (met route), comments: Comment[] }` |
| PATCH   | `/activities/:id`         | `{ title?, notes?, visibility?, type? }` | `{ activity }` |
| DELETE  | `/activities/:id`         | –                                  | `204`    |
| POST    | `/activities/:id/kudos`   | –                                  | `{ kudosCount, hasKudoed: true }` |
| DELETE  | `/activities/:id/kudos`   | –                                  | `{ kudosCount, hasKudoed: false }` |
| POST    | `/activities/:id/comments`| `{ body }` (1–500 tekens)          | `201 { comment }` |
| DELETE  | `/comments/:id`           | –                                  | `204`    |

`ActivityInput`:

```json
{
  "clientId": "uuid (verplicht)",
  "type": "run",
  "title": "optioneel, max 80 tekens",
  "notes": "optioneel, max 2000 tekens",
  "startedAt": "ISO 8601",
  "durationSeconds": 1820,
  "distanceMeters": 5230.4,
  "elevationGainMeters": 31,
  "activeEnergyKcal": 412,
  "avgHeartRate": 152,
  "maxHeartRate": 178,
  "source": "watch",
  "visibility": "friends (optioneel; standaard de voorkeur van de gebruiker)",
  "route": [[52.3702, 4.8952], [52.3705, 4.8961]]
}
```

Alleen `clientId`, `type`, `startedAt` en `durationSeconds` zijn verplicht. `route` bevat maximaal 1000 punten
(de app dunt langere routes uit).

Paginering: `nextCursor` is de `startedAt` van de laatste activiteit; geef hem mee als `before`.

### Feed en voortgang

| Methode | Pad            | Query                                   | Antwoord |
| ------- | -------------- | --------------------------------------- | -------- |
| GET     | `/feed`        | `?before=<iso>&limit=<1-50>`            | `{ activities: Activity[], nextCursor }` – eigen activiteiten + die van vrienden (`friends`/`public`) |
| GET     | `/stats`       | `?weeks=<1-52>&tz=Europe/Amsterdam`     | `Stats`  |
| GET     | `/leaderboard` | `?metric=duration\|distance\|count&tz=…` | `Leaderboard` – ik + vrienden, deze week |

`Stats`:

```json
{
  "thisWeek": { "durationSeconds": 5400, "distanceMeters": 15200, "activeEnergyKcal": 1210, "count": 3, "goalMinutes": 150 },
  "weekly": [ { "weekStart": "2026-11-09", "durationSeconds": 5400, "distanceMeters": 15200, "count": 3 } ],
  "byType": [ { "type": "run", "count": 9, "durationSeconds": 16200, "distanceMeters": 45100 } ],
  "totals": { "count": 120, "durationSeconds": 310000, "distanceMeters": 890000 },
  "currentStreakWeeks": 4
}
```

- `weekly` loopt van oud naar nieuw, bevat altijd precies `weeks` weken (ook lege) en weken beginnen op maandag in tijdzone `tz`
- `byType` gaat over dezelfde periode als `weekly`; `totals` over alles
- `currentStreakWeeks`: aantal aaneengesloten weken met minstens één activiteit (de lopende week telt mee zodra er een activiteit is)

`Leaderboard`:

```json
{
  "metric": "duration",
  "weekStart": "2026-11-09",
  "entries": [ { "rank": 1, "user": { …UserSummary }, "value": 5400, "count": 3, "isMe": true } ]
}
```

### Vrienden

| Methode | Pad                             | Body / query        | Antwoord |
| ------- | ------------------------------- | ------------------- | -------- |
| GET     | `/friends`                      | –                   | `{ friends: UserSummary[], incoming: FriendRequest[], outgoing: FriendRequest[] }` |
| POST    | `/friends/requests`             | `{ username }`      | `201 { status: "requested" \| "friends" }` (wordt direct `friends` als de ander jou al had uitgenodigd) |
| POST    | `/friends/requests/:id/accept`  | –                   | `{ status: "friends" }` |
| DELETE  | `/friends/requests/:id`         | –                   | `204` (weigeren of intrekken) |
| DELETE  | `/friends/:userId`              | –                   | `204` (vriendschap beëindigen) |
| GET     | `/users/search`                 | `?q=<min 2 tekens>` | `{ users: (UserSummary & { relation })[] }` |
| GET     | `/users/:username`              | –                   | `Profile` |

`FriendRequest`: `{ "id": "…", "user": UserSummary, "createdAt": "…" }`

`relation`: `self`, `friends`, `outgoing` (ik heb uitgenodigd), `incoming` (ik ben uitgenodigd), `none`

`Profile`:

```json
{
  "user": { "id": "…", "username": "…", "displayName": "…", "bio": "", "createdAt": "…" },
  "relation": "friends",
  "requestId": null,
  "stats": { "count": 120, "durationSeconds": 310000, "distanceMeters": 890000 },
  "activities": [ …Activity ]
}
```

`GET /users/:username` werkt ook zonder login; dan zijn alleen `public` activiteiten zichtbaar.
`requestId` is gevuld bij `incoming`/`outgoing`, zodat je het verzoek kunt accepteren of intrekken.
