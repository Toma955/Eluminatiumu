/**
 * Eluminatium – pretraživač za Alexandria (app browser).
 * Ne pretražuje web – pretražuje samo ono što ima kod sebe u app library (katalog: data/catalog, apps).
 * Servira Swift aplikacije (index.alexandria / index.swift).
 */

const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const archiver = require('archiver');
const { PassThrough } = require('stream');

const app = express();
const PORT = process.env.PORT || 3847;
const NODE_ENV = process.env.NODE_ENV || 'development';

const APPS_DIR = process.env.APPS_DIR || path.join(__dirname, 'apps');
const UI_DIR = process.env.UI_DIR || path.join(APPS_DIR, 'eluminatium-ui');
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const ICONS_DIR = process.env.ICONS_DIR || path.join(__dirname, 'icons');
const DESCRIPTIONS_DIR = process.env.DESCRIPTIONS_DIR || path.join(__dirname, 'descriptions');
const HASHTABLE_PATH = path.join(DATA_DIR, 'hashtable.json');

const corsOptions = process.env.CORS_ORIGIN
  ? { origin: process.env.CORS_ORIGIN.split(',').map((o) => o.trim()) }
  : {};

function getClientIp(req) {
  return req.get('x-forwarded-for')?.split(',')[0]?.trim() || req.get('x-real-ip') || req.socket?.remoteAddress || req.connection?.remoteAddress || '?';
}

function logTime() {
  const now = new Date();
  const d = String(now.getDate()).padStart(2, '0');
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const y = now.getFullYear();
  const h = String(now.getHours()).padStart(2, '0');
  const min = String(now.getMinutes()).padStart(2, '0');
  const s = String(now.getSeconds()).padStart(2, '0');
  return `${d}.${m}.${y} ${h}:${min}:${s}`;
}

app.use((req, res, next) => {
  const ip = getClientIp(req);
  const start = Date.now();
  res.on('finish', () => {
    const ts = logTime();
    const method = req.method;
    const path = req.originalUrl || req.url;
    const status = res.statusCode;
    const duration = Date.now() - start;
    let detail = '';
    if (req.path === '/api/search' && req.query.q !== undefined) {
      detail = ` | tražio="${req.query.q}"`;
    } else if (req.path.startsWith('/api/apps/')) {
      const parts = req.path.split('/').filter(Boolean);
      const id = parts[2]; // api, apps, :id
      if (id) detail = ` | webapp=${id}`;
      if (req.path.endsWith('/download')) detail += ' | download';
      else if (req.path.endsWith('/dsl')) detail += ' | dsl';
    } else if (req.path === '/api/ui') {
      detail = ' | spojio se (UI pretraživača)';
    } else if (req.path.startsWith('/api/icons/')) {
      const parts = req.path.split('/').filter(Boolean);
      detail = ` | ikona ${parts[2] || ''}`;
    }
    console.log(`[${ts}] IP=${ip} | ${method} ${path} | ${status} | ${duration}ms${detail}`);
  });
  next();
});

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

// GET /api/ui – Swift kod za pretraživač (Alexandria format)
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

// HasTable – hash svake zipane aplikacije (SHA-256), zapis u data/hashtable.json
async function buildHashtable() {
  const apps = loadAppsIndex();
  const table = {};
  for (const app of apps) {
    const zipPath = path.join(APPS_DIR, app.zipFile || `${app.id}.zip`);
    const folderPath = path.join(APPS_DIR, app.id);
    let buf = null;
    if (fs.existsSync(zipPath) && fs.statSync(zipPath).isFile()) {
      buf = await fs.promises.readFile(zipPath);
    } else if (fs.existsSync(folderPath) && fs.statSync(folderPath).isDirectory()) {
      buf = await new Promise((resolve, reject) => {
        const chunks = [];
        const collector = new PassThrough();
        collector.on('data', (c) => chunks.push(c));
        collector.on('end', () => resolve(Buffer.concat(chunks)));
        collector.on('error', reject);
        const archive = archiver('zip', { zlib: { level: 9 } });
        archive.on('error', reject);
        archive.pipe(collector);
        archive.directory(folderPath, false);
        archive.finalize();
      });
    }
    if (buf && buf.length > 0) {
      table[app.id] = crypto.createHash('sha256').update(buf).digest('hex');
    }
  }
  await fs.promises.mkdir(DATA_DIR, { recursive: true });
  await fs.promises.writeFile(HASHTABLE_PATH, JSON.stringify(table, null, 2), 'utf8');
  return table;
}

function loadHashtable() {
  if (fs.existsSync(HASHTABLE_PATH)) {
    try {
      return JSON.parse(fs.readFileSync(HASHTABLE_PATH, 'utf8'));
    } catch {
      return {};
    }
  }
  return {};
}

let hashtableCache = {};

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

// Pretraga samo u app library (katalog) – pretraživač ne pretražuje web
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
  const zipHash = hashtableCache[app.id] ?? null;
  return { ...app, iconUrl: `${base}/api/icons/${app.id}`, zipHash };
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

// GET /api/apps – lista svih aplikacija iz kataloga (s iconUrl)
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

// GET /api/apps/:id/dsl – Swift izvornik (za Alexandria app browser)
app.get('/api/apps/:id/dsl', (req, res) => {
  const apps = loadAppsIndex();
  const app = apps.find((a) => a.id === req.params.id);
  if (!app) {
    return res.status(404).json({ exists: false, message: 'Nema' });
  }
  const dslPath = path.join(APPS_DIR, app.id, 'index.alexandria');
  if (!fs.existsSync(dslPath)) {
    return res.status(404).json({ exists: false, message: 'Swift datoteka nije pronađena' });
  }
  const dsl = fs.readFileSync(dslPath, 'utf8');
  res.json({ exists: true, dsl, app: { id: app.id, name: app.name } });
});

// GET /api/apps/:id/download – preuzmi zip (ako ne postoji, kreira iz mape)
app.get('/api/apps/:id/download', (req, res) => {
  const apps = loadAppsIndex();
  const app = apps.find((a) => a.id === req.params.id);
  if (!app) {
    return res.status(404).json({ exists: false, message: 'Nema' });
  }
  const zipPath = path.join(APPS_DIR, app.zipFile || `${app.id}.zip`);
  const folderPath = path.join(APPS_DIR, app.id);

  if (fs.existsSync(zipPath)) {
    return res.download(zipPath, path.basename(zipPath));
  }
  if (fs.existsSync(folderPath) && fs.statSync(folderPath).isDirectory()) {
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${app.id}.zip"`);
    const archive = archiver('zip', { zlib: { level: 9 } });
    archive.on('error', (err) => {
      res.status(500).json({ exists: false, message: err.message });
    });
    archive.pipe(res);
    archive.directory(folderPath, false);
    archive.finalize();
    return;
  }
  res.status(404).json({ exists: false, message: 'Zip ili mapa aplikacije nije pronađena' });
});

// GET /health
app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'eluminatium-search-engine' });
});

if (!fs.existsSync(APPS_DIR)) {
  fs.mkdirSync(APPS_DIR, { recursive: true });
}

(async () => {
  hashtableCache = loadHashtable();
  const hadData = Object.keys(hashtableCache).length > 0;
  if (hadData) {
    console.log(`HasTable: učitano ${Object.keys(hashtableCache).length} hash-eva iz data/hashtable.json`);
  }
  try {
    const built = await buildHashtable();
    hashtableCache = built;
    const count = Object.keys(built).length;
    console.log(`HasTable: ${count} aplikacija (zip hash zapisan u data/hashtable.json)`);
  } catch (err) {
    console.warn('HasTable: nije moguće izgraditi (koristi postojeći ili prazan):', err.message);
  }

  app.listen(PORT, () => {
    console.log(`Eluminatium Search Engine (${NODE_ENV}): port ${PORT}`);
    console.log(`  /api/ui – Swift kod za pretraživač`);
    console.log(`  /api/search?q=... – pretraga`);
    console.log(`  /api/apps/:id/dsl – Swift izvornik aplikacije`);
    console.log(`  /api/apps/:id/download – zip`);
  });
})();
