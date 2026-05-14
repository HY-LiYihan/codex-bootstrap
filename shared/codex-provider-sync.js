#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

function exists(file) {
  try { return fs.existsSync(file); } catch { return false; }
}

function mkdirp(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function timestamp() {
  const now = new Date();
  const pad = (value) => String(value).padStart(2, '0');
  return [
    now.getFullYear(),
    pad(now.getMonth() + 1),
    pad(now.getDate()),
    pad(now.getHours()),
    pad(now.getMinutes()),
    pad(now.getSeconds()),
  ].join('');
}

function parseTomlString(text, key) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = text.match(new RegExp(`^\\s*${escaped}\\s*=\\s*"((?:\\\\.|[^"])*)"`, 'm'));
  if (!match) return '';
  return match[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
}

function readProvider(codexHome) {
  const configFile = path.join(codexHome, 'config.toml');
  const text = fs.readFileSync(configFile, 'utf8');
  return parseTomlString(text, 'model_provider') || 'custom';
}

function walkRollouts(root) {
  const files = [];
  if (!exists(root)) return files;
  const stack = [root];
  while (stack.length) {
    const current = stack.pop();
    let entries = [];
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const target = path.join(current, entry.name);
      if (entry.isDirectory()) stack.push(target);
      else if (entry.isFile() && /^rollout-.*\.jsonl$/.test(entry.name)) files.push(target);
    }
  }
  return files.sort();
}

function relativeBackupName(codexHome, file) {
  return path.relative(codexHome, file).split(path.sep).join('__');
}

function copyIfExists(file, destDir, label, manifest, dryRun) {
  if (!exists(file)) return;
  const backupPath = path.join(destDir, label);
  manifest.files.push({ target: file, backup: backupPath });
  if (!dryRun) {
    mkdirp(path.dirname(backupPath));
    fs.copyFileSync(file, backupPath);
    try { fs.chmodSync(backupPath, 0o600); } catch {}
  }
}

function createBackup(codexHome, changedRollouts, dryRun) {
  const id = timestamp();
  const dir = path.join(codexHome, 'backups_state', 'provider-sync', id);
  const manifest = {
    id,
    createdAt: new Date().toISOString(),
    changedRollouts: changedRollouts.length,
    files: [],
  };

  if (!dryRun) mkdirp(dir);
  copyIfExists(path.join(codexHome, 'config.toml'), dir, 'config.toml', manifest, dryRun);
  ['state_5.sqlite', 'state_5.sqlite-wal', 'state_5.sqlite-shm'].forEach((name) => {
    copyIfExists(path.join(codexHome, name), dir, name, manifest, dryRun);
  });

  for (const file of changedRollouts) {
    const backupPath = path.join(dir, 'rollouts', relativeBackupName(codexHome, file));
    manifest.files.push({ target: file, backup: backupPath });
    if (!dryRun) {
      mkdirp(path.dirname(backupPath));
      fs.copyFileSync(file, backupPath);
      try { fs.chmodSync(backupPath, 0o600); } catch {}
    }
  }

  if (!dryRun) {
    fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n', { mode: 0o600 });
  }
  return { id, dir, manifest };
}

function plannedRolloutChanges(codexHome, provider) {
  const roots = [
    path.join(codexHome, 'sessions'),
    path.join(codexHome, 'archived_sessions'),
  ];
  const changes = [];
  for (const file of roots.flatMap(walkRollouts)) {
    let text = '';
    try { text = fs.readFileSync(file, 'utf8'); } catch { continue; }
    if (!text) continue;
    const newlineIndex = text.indexOf('\n');
    const firstLine = newlineIndex === -1 ? text : text.slice(0, newlineIndex);
    const rest = newlineIndex === -1 ? '' : text.slice(newlineIndex);
    let meta;
    try { meta = JSON.parse(firstLine); } catch { continue; }
    if (meta?.type !== 'session_meta') continue;
    if (!meta.payload || typeof meta.payload !== 'object') continue;
    if (meta.payload.model_provider === provider) continue;
    const previousProvider = meta.payload.model_provider || '';
    meta.payload.model_provider = provider;
    const nextFirstLine = JSON.stringify(meta);
    changes.push({ file, previousProvider, nextText: `${nextFirstLine}${rest}` });
  }
  return changes;
}

function applyRolloutChanges(changes, dryRun) {
  for (const change of changes) {
    if (dryRun) continue;
    let mode;
    try { mode = fs.statSync(change.file).mode; } catch { mode = undefined; }
    const tmp = `${change.file}.tmp.${process.pid}`;
    fs.writeFileSync(tmp, change.nextText, 'utf8');
    if (mode) {
      try { fs.chmodSync(tmp, mode); } catch {}
    }
    fs.renameSync(tmp, change.file);
  }
}

function escapeSql(value) {
  return String(value).replace(/'/g, "''");
}

function runSqlite(dbFile, provider, dryRun, logger) {
  if (!exists(dbFile)) return { status: 'missing', changed: 0 };
  const sqlitePath = 'sqlite3';
  const probe = spawnSync(sqlitePath, ['--version'], { encoding: 'utf8' });
  if (probe.error && probe.error.code === 'ENOENT') {
    logger.warn('sqlite3 not found; skipped state_5.sqlite provider sync');
    return { status: 'skipped', changed: 0 };
  }

  const schema = spawnSync(sqlitePath, [dbFile, "SELECT COUNT(*) FROM pragma_table_info('threads') WHERE name='model_provider';"], { encoding: 'utf8' });
  if (schema.status !== 0) {
    logger.warn('state_5.sqlite is unavailable or locked; skipped SQLite provider sync');
    return { status: 'skipped', changed: 0 };
  }
  if (String(schema.stdout).trim() !== '1') return { status: 'no-column', changed: 0 };

  const countSql = `SELECT COUNT(*) FROM threads WHERE COALESCE(model_provider, '') <> '${escapeSql(provider)}';`;
  const countResult = spawnSync(sqlitePath, [dbFile, countSql], { encoding: 'utf8' });
  if (countResult.status !== 0) {
    logger.warn('state_5.sqlite is unavailable or locked; skipped SQLite provider sync');
    return { status: 'skipped', changed: 0 };
  }
  const changed = Number(String(countResult.stdout).trim() || 0);
  if (!changed || dryRun) return { status: 'ok', changed };

  const updateSql = `UPDATE threads SET model_provider = '${escapeSql(provider)}' WHERE COALESCE(model_provider, '') <> '${escapeSql(provider)}';`;
  const updateResult = spawnSync(sqlitePath, [dbFile, updateSql], { encoding: 'utf8' });
  if (updateResult.status !== 0) {
    logger.warn('state_5.sqlite is unavailable or locked; skipped SQLite provider sync');
    return { status: 'skipped', changed: 0 };
  }
  return { status: 'ok', changed };
}

function defaultLogger(quiet = false) {
  return {
    info: (message) => { if (!quiet) console.log(`[INFO] ${message}`); },
    ok: (message) => { if (!quiet) console.log(`[OK] ${message}`); },
    warn: (message) => { if (!quiet) console.warn(`[WARN] ${message}`); },
  };
}

function syncProviderHistory(options = {}) {
  const codexHome = options.codexHome || process.env.CODEX_HOME || path.join(os.homedir(), '.codex');
  const dryRun = Boolean(options.dryRun);
  const logger = options.logger || defaultLogger(Boolean(options.quiet));
  const configFile = path.join(codexHome, 'config.toml');

  if (!exists(configFile) && !options.provider) {
    logger.warn(`Codex config not found; skipped provider history sync: ${configFile}`);
    return { provider: '', rolloutChanged: 0, sqliteChanged: 0, backupDir: '' };
  }

  const provider = options.provider || readProvider(codexHome);
  const changes = plannedRolloutChanges(codexHome, provider);
  const sqliteDb = path.join(codexHome, 'state_5.sqlite');
  const shouldBackup = changes.length > 0 || exists(sqliteDb);
  const backup = shouldBackup ? createBackup(codexHome, changes.map((item) => item.file), dryRun) : null;

  applyRolloutChanges(changes, dryRun);
  const sqlite = runSqlite(sqliteDb, provider, dryRun, logger);

  const action = dryRun ? 'would sync' : 'synced';
  logger.ok(`${action} provider history to "${provider}": rollouts=${changes.length}, sqlite=${sqlite.changed}`);
  if (backup) {
    logger.info(`${dryRun ? 'Would create' : 'Created'} provider-sync backup: ${backup.dir}`);
  }

  return {
    provider,
    rolloutChanged: changes.length,
    sqliteChanged: sqlite.changed,
    sqliteStatus: sqlite.status,
    backupDir: backup ? backup.dir : '',
  };
}

function parseArgs(argv) {
  const args = { codexHome: '', dryRun: false, json: false, quiet: false, provider: '' };
  for (let i = 0; i < argv.length; i += 1) {
    const item = argv[i];
    if (item === '--codex-home') { args.codexHome = argv[++i] || ''; continue; }
    if (item === '--provider') { args.provider = argv[++i] || ''; continue; }
    if (item === '--dry-run') { args.dryRun = true; continue; }
    if (item === '--json') { args.json = true; continue; }
    if (item === '--quiet') { args.quiet = true; continue; }
    if (item === '-h' || item === '--help') {
      console.log('Usage: node shared/codex-provider-sync.js [--codex-home DIR] [--provider NAME] [--dry-run] [--json]');
      process.exit(0);
    }
    throw new Error(`Unknown option: ${item}`);
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const result = syncProviderHistory({
    codexHome: args.codexHome || undefined,
    provider: args.provider || undefined,
    dryRun: args.dryRun,
    quiet: args.json || args.quiet,
  });
  if (args.json) console.log(JSON.stringify(result, null, 2));
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error(`[WARN] Provider history sync skipped: ${err.message}`);
    process.exit(0);
  }
}

module.exports = { syncProviderHistory };
