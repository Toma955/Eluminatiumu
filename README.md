# Eluminatium pretraživač

Node.js backend za Alexandria – servira zipane webapp-ove (Alexandria DSL).

## Pokretanje

```bash
npm install
npm start
```

Server radi na `http://localhost:3847`.

## API

| Endpoint | Opis |
|---------|------|
| `GET /api/apps` | Lista svih aplikacija |
| `GET /api/search?q=...` | Pretraga po imenu/opisu |
| `GET /api/apps/:id` | Detalji aplikacije |
| `GET /api/apps/:id/download` | Preuzmi .zip |
| `GET /health` | Health check |

## Dodavanje novih appova

1. Kreiraj folder u `apps/` (npr. `apps/moj-app/`)
2. Dodaj `index.alexandria` (ili `main.alexandria` / `app.alexandria`)
3. Zipaj: `cd apps/moj-app && zip -r ../moj-app.zip .`
4. Dodaj u `apps/index.json`:

```json
{
  "id": "moj-app",
  "name": "Moj App",
  "description": "Opis",
  "zipFile": "moj-app.zip"
}
```
