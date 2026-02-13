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
const NODE_ENV = process.env.NODE_ENV || 'development';

const APPS_DIR = process.env.APPS_DIR || path.join(__dirname, 'apps');
const UI_DIR = process.env.UI_DIR || path.join(APPS_DIR, 'eluminatium-ui');
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const ICONS_DIR = process.env.ICONS_DIR || path.join(__dirname, 'icons');
const DESCRIPTIONS_DIR = process.env.DESCRIPTIONS_DIR || path.join(__dirname, 'descriptions');

const corsOptions = process.env.CORS_ORIGIN
  ? { origin: process.env.CORS_ORIGIN.split(',').map((o) => o.trim()) }
  : {};

app.use(cors(corsOptions));
app.use(express.json());

// GET / – root (za testiranje veze, inače 404)
app.get('/', (req, res) => {
  res.json({
    service: 'eluminatium-search-engine',
    version: '1.0',
    endpoints: ['/api/ui', '/api/search', '/api/apps', '/api/icons/:id', '/health']
  });
});

// GET /api/ui – Alexandria DSL za pretraživač (prvo se uspostavlja veza, pa se šalju Swift datoteke)
app.get('/api/ui', (req, res) => {
  const dslPath = path.join(UI_DIR, 'index.alexandria');
  if (!fs.existsSync(dslPath)) {
    return res.status(404).json({ exists: false, message: 'UI nije pronađen' });
  }
  const dsl = fs.readFileSync(dslPath, 'utf8');
  res.json({ exists: true, dsl });
});

// Registar aplikacija – data/catalog.json (opisi) ili apps/index.json
function loadAppsIndex() {
  const catalogPath = path.join(DATA_DIR, 'catalog.json');
  const indexPath = path.join(APPS_DIR, 'index.json');
  let apps = [];
  if (fs.existsSync(catalogPath)) {
    try {
      apps = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
    } catch {
      apps = [];
    }
  }
  if (apps.length === 0 && fs.existsSync(indexPath)) {
    try {
      apps = JSON.parse(fs.readFileSync(indexPath, 'utf8'));
    } catch {
      apps = [];
    }
  }
  // Spoji s descriptions/ ako postoje
  return apps.map((app) => {
    const descPath = path.join(DESCRIPTIONS_DIR, `${app.id}.json`);
    if (fs.existsSync(descPath)) {
      try {
        const extra = JSON.parse(fs.readFileSync(descPath, 'utf8'));
        return { ...app, ...extra };
      } catch {
        return app;
      }
    }
    return app;
  });
}

// Pretraga – indeks za brzu pretragu (catalog + descriptions + keywords)
function buildSearchIndex(apps) {
  return apps.map((app) => ({
    ...app,
    _searchText: [
      app.id || '',
      app.name || '',
      app.description || '',
      (app.keywords || []).join(' '),
      app.category || ''
    ]
      .join(' ')
      .toLowerCase()
  }));
}

// Pretraga – catalog + descriptions + keywords; rezultati se šalju na Alexandria browser
app.get('/api/search', (req, res) => {
  const q = (req.query.q || '').toLowerCase().trim();
  const apps = loadAppsIndex();
  const index = buildSearchIndex(apps);

  if (!q) {
    const withIconUrl = index.map((a) => addIconUrl(a, req));
    return res.json({ exists: true, apps: withIconUrl });
  }

  const filtered = index.filter((a) => a._searchText.includes(q));
  const withIconUrl = filtered.map((a) => {
    const { _searchText, ...app } = a;
    return addIconUrl(app, req);
  });

  if (withIconUrl.length === 0) {
    return res.json({ exists: false, message: 'Nema', apps: [] });
  }

  res.json({ exists: true, apps: withIconUrl });
});

function addIconUrl(app, req) {
  const base = `${req.protocol}://${req.get('host')}`;
  const iconFile = app.icon || `${app.id}.png`;
  return { ...app, iconUrl: `${base}/api/icons/${app.id}` };
}

// GET /api/icons/:id – ikona aplikacije
app.get('/api/icons/:id', (req, res) => {
  const apps = loadAppsIndex();
  const app = apps.find((a) => a.id === req.params.id);
  const iconFile = app?.icon || `${req.params.id}.png`;
  const iconPath = path.join(ICONS_DIR, iconFile);
  if (!fs.existsSync(iconPath)) {
    return res.status(404).json({ exists: false, message: 'Ikona nije pronađena' });
  }
  res.sendFile(iconPath);
});

// GET /api/apps – lista svih aplikacija (s iconUrl za Alexandria browser)
app.get('/api/apps', (req, res) => {
  const apps = loadAppsIndex();
  const withIconUrl = apps.map((a) => addIconUrl(a, req));
  res.json({ exists: true, apps: withIconUrl });
});

// GET /api/apps/:id – detalji jedne aplikacije (s iconUrl)
app.get('/api/apps/:id', (req, res) => {
  const apps = loadAppsIndex();
  const app = apps.find((a) => a.id === req.params.id);
  if (!app) {
    return res.json({ exists: false, message: 'Nema' });
  }
  res.json({ exists: true, app: addIconUrl(app, req) });
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
  console.log(`Eluminatium Search Engine (${NODE_ENV}): port ${PORT}`);
  console.log(`  /api/ui – Swift/DSL za render pretraživača`);
  console.log(`  /api/search?q=... – pretraga`);
  console.log(`  /api/apps/:id/dsl – DSL aplikacije`);
  console.log(`  /api/apps/:id/download – zip`);
});
