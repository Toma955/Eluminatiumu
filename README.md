# Eluminatium Search Engine

Node.js backend za Alexandria – search engine za aplikacije.  
U tražilicu se upisuje ime aplikacije: **ako postoji vrati je, ako ne postoji vrati "nema"**.  
Mapa `apps/` sadrži zipane aplikacije.

## Pokretanje

```bash
npm install
npm start
```

Server: `http://localhost:3847`

## Varijable okruženja

| Varijabla | Default | Opis |
|-----------|---------|------|
| `PORT` | `3847` | Port (Render postavlja automatski) |
| `NODE_ENV` | `development` | `production` / `development` |
| `APPS_DIR` | `./apps` | Putanja do mape s aplikacijama |
| `UI_DIR` | `{APPS_DIR}/eluminatium-ui` | Putanja do UI pretraživača |
| `CORS_ORIGIN` | *(sve)* | Dozvoljeni origini, odvojeni zarezom (npr. `https://app.example.com`) |

## Deploy na Render

1. Push repo na GitHub
2. [Render Dashboard](https://dashboard.render.com) → **New** → **Web Service**
3. Spoji GitHub repo `Toma955/Eluminatiumu`
4. Render automatski detektira `render.yaml` (Node, npm install, npm start)
5. Deploy – URL: `https://eluminatium.onrender.com` (ili custom)

Zatim u Alexandria: Postavke → Pretraživači → Dodaj pretraživač → URL s Rendera

## Flow

1. **Alexandria otvara Eluminatium** → prvo uspostavlja vezu s backendom
2. **Backend šalje Swift/DSL datoteke** (`GET /api/ui`) → Alexandria ih renderira kao pretraživač
3. **Korisnik upisuje u tražilicu** → pretraga, ako postoji vrati, ako ne vrati "nema"

## API

| Endpoint | Opis |
|---------|------|
| `GET /api/ui` | **Prvo se poziva** – Swift/DSL za render pretraživača |
| `GET /api/search?q=...` | Pretraga – postoji → `{ exists: true, apps: [...] }`, nema → `{ exists: false, message: "Nema" }` |
| `GET /api/apps` | Lista svih aplikacija |
| `GET /api/apps/:id` | Detalji – postoji/nema |
| `GET /api/apps/:id/dsl` | Alexandria DSL izvornik (za render u browseru) |
| `GET /api/apps/:id/download` | Preuzmi .zip |
| `GET /health` | Health check |

## Struktura apps/

```
apps/
├── index.json              # Registar aplikacija
├── eluminatium-ui/         # UI pretraživača (šalje se prvo preko /api/ui)
│   └── index.alexandria
├── dobrodosli.zip
├── dobrodosli/
│   └── index.alexandria
├── kalkulator.zip
├── kalkulator/
│   └── index.alexandria
...
```

## Dodavanje novih appova

1. Kreiraj `apps/moj-app/index.alexandria`
2. Zipaj: `cd apps/moj-app && zip -r ../moj-app.zip .`
3. Dodaj u `apps/index.json`:

```json
{
  "id": "moj-app",
  "name": "Moj App",
  "description": "Opis",
  "zipFile": "moj-app.zip"
}
```
