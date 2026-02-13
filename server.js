/**
 * Eluminatium Search Engine
 * Node.js backend za Alexandria – pretraživač aplikacija.
 * U tražilicu se upisuje ime aplikacije: ako postoji vrati je, ako ne postoji vrati "nema".
 * Mapa apps/ sadrži zipane aplikacije.
 */

const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3847;

app.use(cors());
app.use(express.json());

const APPS_DIR = path.join(__dirname, 'apps');
const UI_DIR = path.join(__dirname, 'apps', 'eluminatium-ui');

// GET /api/ui – Alexandria DSL za pretraživač (prvo se uspostavlja veza, pa se šalju Swift datoteke)
app.get('/api/ui', (req, res) => {
  const dslPath = path.join(UI_DIR, 'index.alexandria');
  if (!fs.existsSync(dslPath)) {
    return res.status(404).json({ exists: false, message: 'UI nije pronađen' });
  }
  const dsl = fs.readFileSync(dslPath, 'utf8');
  res.json({ exists: true, dsl });
});

// Registar aplikacija (apps/index.json)
function loadAppsIndex() {
  const indexPath = path.join(APPS_DIR, 'index.json');
  if (!fs.existsSync(indexPath)) return [];
  try {
    const data = fs.readFileSync(indexPath, 'utf8');
    return JSON.parse(data);
  } catch {
    return [];
  }
}

// Pretraga – kao Google: upišeš aplikaciju, ako postoji vrati je, ako ne vrati nema
app.get('/api/search', (req, res) => {
  const q = (req.query.q || '').toLowerCase().trim();
  const apps = loadAppsIndex();

  if (!q) {
    return res.json({ exists: true, apps });
  }

  const filtered = apps.filter(
    (a) =>
      (a.name || '').toLowerCase().includes(q) ||
      (a.description || '').toLowerCase().includes(q) ||
      (a.id || '').toLowerCase().includes(q)
  );

  if (filtered.length === 0) {
    return res.json({ exists: false, message: 'Nema', apps: [] });
  }

  res.json({ exists: true, apps: filtered });
});

// GET /api/apps – lista svih aplikacija
app.get('/api/apps', (req, res) => {
  const apps = loadAppsIndex();
  res.json({ exists: true, apps });
});

// GET /api/apps/:id – detalji jedne aplikacije (ako postoji)
app.get('/api/apps/:id', (req, res) => {
  const apps = loadAppsIndex();
  const app = apps.find((a) => a.id === req.params.id);
  if (!app) {
    return res.json({ exists: false, message: 'Nema' });
  }
  res.json({ exists: true, app });
});

// GET /api/apps/:id/dsl – Alexandria DSL izvornik (za render u browseru)
app.get('/api/apps/:id/dsl', (req, res) => {
  const apps = loadAppsIndex();
  const app = apps.find((a) => a.id === req.params.id);
  if (!app) {
    return res.status(404).json({ exists: false, message: 'Nema' });
  }
  const dslPath = path.join(APPS_DIR, app.id, 'index.alexandria');
  if (!fs.existsSync(dslPath)) {
    return res.status(404).json({ exists: false, message: 'DSL datoteka nije pronađena' });
  }
  const dsl = fs.readFileSync(dslPath, 'utf8');
  res.json({ exists: true, dsl, app: { id: app.id, name: app.name } });
});

// GET /api/apps/:id/download – preuzmi zip
app.get('/api/apps/:id/download', (req, res) => {
  const apps = loadAppsIndex();
  const app = apps.find((a) => a.id === req.params.id);
  if (!app || !app.zipFile) {
    return res.status(404).json({ exists: false, message: 'Nema' });
  }
  const zipPath = path.join(APPS_DIR, app.zipFile);
  if (!fs.existsSync(zipPath)) {
    return res.status(404).json({ exists: false, message: 'Zip nije pronađen' });
  }
  res.download(zipPath, path.basename(app.zipFile));
});

// GET /health
app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'eluminatium-search-engine' });
});

if (!fs.existsSync(APPS_DIR)) {
  fs.mkdirSync(APPS_DIR, { recursive: true });
}

app.listen(PORT, () => {
  console.log(`Eluminatium Search Engine: http://localhost:${PORT}`);
  console.log(`  /api/ui – Swift/DSL datoteke za render pretraživača (prvo se poziva)`);
  console.log(`  /api/search?q=... – pretraga (postoji → apps, nema → exists: false)`);
  console.log(`  /api/apps/:id/dsl – DSL aplikacije`);
  console.log(`  /api/apps/:id/download – zip`);
});
