# Eluminatium

**Pretraživač kataloga** za Alexandria (app browser). Eluminatium pretražuje **isključivo svoj katalog** (data/catalog, apps) – **nema pretrage na webu**. Sve aplikacije su u Swiftu (Alexandria format).

## Struktura mapa

| Mapa | Namjena |
|------|---------|
| `data/catalog.json` | JSON s opisima svih aplikacija (id, name, description, zipFile, icon) |
| `icons/` | Ikone aplikacija (PNG, npr. google.png, youtube.png) |
| `descriptions/` | Opcionalni JSON opisi po aplikaciji (keywords, category) za pretragu |
| `apps/` | Swift aplikacije: `index.alexandria` ili `index.swift` po appu, zip za download (katalog, ne web) |

## API

- `GET /api/search?q=...` – pretraga **samo u Eluminatium katalogu** (ne na webu); rezultati za Alexandria app browser
- `GET /api/apps` – lista svih aplikacija iz kataloga (s iconUrl)
- `GET /api/icons/:id` – ikona aplikacije
- `GET /api/apps/:id/download` – preuzmi zip
- `GET /api/ui` – Swift kod za pretraživač

## Pretraga

Eluminatium pretražuje **isključivo svoj katalog**: `data/catalog.json` + `descriptions/*.json` (keywords, category). **Nema pristupa webu.** Kad se pronađe aplikacija, Alexandria (app browser) prikazuje rezultate i korisnik može instalirati i otvoriti app.

## Format aplikacija

Sve aplikacije moraju biti napisane u **Swiftu** (Alexandria format): datoteka `index.alexandria` ili `index.swift` u zipu. Alexandria (app browser) parsira Swift kod i renderira u SwiftUI. Eluminatium servira samo Swift sadržaj iz svog kataloga – nema web sadržaja.

---
*Ažurirano za sync s Alexandria klijentom.*
