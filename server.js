/**
 * Eluminatium pretraživač
 * Node.js backend za Alexandria – servira zipane webapp-ove
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

// GET /api/apps – lista svih aplikacija
app.get('/api/apps', (req, res) => {
  const apps = loadAppsIndex();
  res.json({ apps });
});

// GET /api/search?q=... – pretraga po imenu/opisu
app.get('/api/search', (req, res) => {
  const q = (req.query.q || '').toLowerCase().trim();
  const apps = loadAppsIndex();
  if (!q) {
    return res.json({ apps });
  }
  const filtered = apps.filter(
    (a) =>
      (a.name || '').toLowerCase().includes(q) ||
      (a.description || '').toLowerCase().includes(q) ||
      (a.id || '').toLowerCase().includes(q)
  );
  res.json({ apps: filtered });
});

// GET /api/apps/:id – detalji jedne aplikacije
app.get('/api/apps/:id', (req, res) => {
  const apps = loadAppsIndex();
  const app = apps.find((a) => a.id === req.params.id);
  if (!app) {
    return res.status(404).json({ error: 'Aplikacija nije pronađena' });
  }
  res.json(app);
});

// GET /api/apps/:id/download – preuzmi zip
app.get('/api/apps/:id/download', (req, res) => {
  const apps = loadAppsIndex();
  const app = apps.find((a) => a.id === req.params.id);
  if (!app || !app.zipFile) {
    return res.status(404).json({ error: 'Aplikacija nije pronađena' });
  }
  const zipPath = path.join(APPS_DIR, app.zipFile);
  if (!fs.existsSync(zipPath)) {
    return res.status(404).json({ error: 'Zip datoteka nije pronađena' });
  }
  res.download(zipPath, path.basename(app.zipFile));
});

// GET /health – health check
app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'eluminatium-pretrazivac' });
});

// Kreiraj apps folder ako ne postoji
if (!fs.existsSync(APPS_DIR)) {
  fs.mkdirSync(APPS_DIR, { recursive: true });
}

app.listen(PORT, () => {
  console.log(`Eluminatium pretraživač: http://localhost:${PORT}`);
  console.log(`  API: /api/apps, /api/search?q=..., /api/apps/:id/download`);
});
