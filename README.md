# Eluminatium

Backend pretraživač za Alexandria browser – Swift aplikacije u zip formatu.

## Struktura mapa

| Mapa | Namjena |
|------|---------|
| `data/catalog.json` | JSON s opisima svih aplikacija (id, name, description, zipFile, icon) |
| `icons/` | Ikone aplikacija (PNG, npr. google.png, youtube.png) |
| `descriptions/` | Opcionalni JSON opisi po aplikaciji (keywords, category) za pretragu |
| `apps/` | Zip datoteke aplikacija i index.json (fallback) |

## API

- `GET /api/search?q=...` – pretraga; rezultati se šalju na Alexandria browser
- `GET /api/apps` – lista svih aplikacija (s iconUrl)
- `GET /api/icons/:id` – ikona aplikacije
- `GET /api/apps/:id/download` – preuzmi zip
- `GET /api/ui` – Swift/DSL za pretraživač

## Pretraga

Pretraga koristi `data/catalog.json` + `descriptions/*.json` (keywords, category).
Kad se pronađe, Alexandria prikazuje rezultate i korisnik može instalirati i otvoriti app.

---
*Ažurirano za sync s Alexandria klijentom.*
