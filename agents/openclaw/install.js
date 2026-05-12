#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const childProcess = require('node:child_process');

const dryRun = process.argv.includes('--dry-run') || process.env.AGENT_BOOTSTRAP_DRY_RUN === '1';
const token = process.env.OPENCLAW_TOKEN || process.env.AGENT_TOKEN || '';
const baseUrl = process.env.OPENCLAW_BASE_URL || process.env.OPENCLAW_API_URL || 'https://node-hk.sssaicode.com/api';
const model = process.env.OPENCLAW_MODEL || 'anthropic/claude-opus-4-7';
const configDir = process.env.OPENCLAW_CONFIG_DIR || path.join(os.homedir(), '.openclaw');

function log(kind, message) { console.log(`[${kind}] ${message}`); }
function fail(message) { console.error(`[ERROR] ${message}`); process.exit(1); }
function mask(value) { return value.length <= 8 ? '<hidden>' : `${value.slice(0, 4)}...${value.slice(-4)}`; }
function ensureDir(dir) { if (!dryRun) fs.mkdirSync(dir, { recursive: true }); }
function backup(file) { if (!fs.existsSync(file)) return; const backupPath = `${file}.backup.${new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14)}`; if (dryRun) log('DRY-RUN', `copy ${file} ${backupPath}`); else fs.copyFileSync(file, backupPath); }
function readJson(file) { try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return {}; } }
function writeJson(file, data) { ensureDir(path.dirname(file)); if (dryRun) log('DRY-RUN', `write ${file}`); else fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8'); }

function mergeOpenclawConfig(existing) {
  const cleanBase = baseUrl.replace(/\/+$/, '');
  const result = Object.assign({}, existing || {});
  result.models = {
    mode: 'merge',
    providers: {
      openai: { baseUrl: `${cleanBase}/v1`, models: [] },
      anthropic: { baseUrl: cleanBase, models: [] },
      google: { baseUrl: `${cleanBase}/v1beta`, models: [] },
    },
  };
  result.agents = { defaults: { model: { primary: model }, models: { [model]: {} } } };
  result.meta = Object.assign({}, result.meta || {}, { lastTouchedAt: new Date().toISOString(), managedBy: 'agent-bootstrap' });
  return result;
}

function mergeAuthProfiles(existing) {
  const result = Object.assign({}, existing || {});
  result.version = 1;
  result.profiles = {
    'openai:default': { type: 'api_key', provider: 'openai', key: token },
    'anthropic:default': { type: 'api_key', provider: 'anthropic', key: token },
    'google:default': { type: 'api_key', provider: 'google', key: token },
  };
  return result;
}

function main() {
  console.log('');
  console.log('+--------------------------------------------------+');
  console.log('| OpenClaw Bootstrap                               |');
  console.log('+--------------------------------------------------+');
  console.log('');

  if (!token) fail('Missing OPENCLAW_TOKEN');
  log('INFO', `Config dir: ${configDir}`);
  log('INFO', `Base URL: ${baseUrl}`);
  log('INFO', `Model: ${model}`);
  log('INFO', `Token: ${mask(token)}`);

  const configPath = path.join(configDir, 'openclaw.json');
  const authPath = path.join(configDir, 'agents', 'main', 'agent', 'auth-profiles.json');
  backup(configPath);
  backup(authPath);
  writeJson(configPath, mergeOpenclawConfig(readJson(configPath)));
  writeJson(authPath, mergeAuthProfiles(readJson(authPath)));
  log('OK', `OpenClaw config ready: ${configPath}`);
  log('OK', `OpenClaw auth ready: ${authPath}`);

  if (!dryRun) {
    try {
      childProcess.execSync('openclaw gateway restart', { stdio: 'inherit', timeout: 15000 });
      log('OK', 'OpenClaw gateway restarted');
    } catch {
      log('WARN', 'Gateway restart failed. If OpenClaw is installed, run: openclaw gateway restart');
    }
  }
  log('INFO', 'Try: openclaw tui');
}

main();
