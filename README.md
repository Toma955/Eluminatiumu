# Eluminatium

Backend pretraživač za Alexandria browser – **samo i isključivo Swift** aplikacije u zip formatu. Nema HTML/CSS/JS – sve aplikacije su napisane u Swiftu (Alexandria format).

## Struktura mapa

| Mapa | Namjena |
|------|---------|
| `data/catalog.json` | JSON s opisima svih aplikacija (id, name, description, zipFile, icon) |
| `icons/` | Ikone aplikacija (PNG, npr. google.png, youtube.png) |
| `descriptions/` | Opcionalni JSON opisi po aplikaciji (keywords, category) za pretragu |
| `apps/` | Swift aplikacije: `index.alexandria` ili `index.swift` po appu, zip za download (samo Swift, nema web) |

## API

- `GET /api/search?q=...` – pretraga; rezultati se šalju na Alexandria browser
- `GET /api/apps` – lista svih aplikacija (s iconUrl)
- `GET /api/icons/:id` – ikona aplikacije
- `GET /api/apps/:id/download` – preuzmi zip
- `GET /api/ui` – Swift kod za pretraživač

## Pretraga

Pretraga koristi `data/catalog.json` + `descriptions/*.json` (keywords, category).
Kad se pronađe, Alexandria prikazuje rezultate i korisnik može instalirati i otvoriti app.

## Format aplikacija

Sve aplikacije moraju biti napisane u **Swiftu** (Alexandria format): datoteka `index.alexandria` ili `index.swift` u zipu. Alexandria parsira Swift kod i renderira u SwiftUI. **HTML, CSS i JavaScript nisu podržani** – Eluminatium servira samo Swift sadržaj.

---
*Ažurirano za sync s Alexandria klijentom.*
