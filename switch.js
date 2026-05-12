#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const HOME = os.homedir();
const STATE_DIR = process.env.AGENT_BOOTSTRAP_HOME || path.join(HOME, '.agent-bootstrap');
const STORE_FILE = path.join(STATE_DIR, 'profiles.json');
const CURRENT_FILE = path.join(STATE_DIR, 'current.json');

const DEFAULTS = {
  codexModel: 'gpt-5.5',
  codexReasoning: 'high',
  codexProviderId: 'custom',
  codexEnvKey: 'CODEX_API_KEY',
  openclawModel: 'anthropic/claude-opus-4-7',
};

function mkdirp(dir) { fs.mkdirSync(dir, { recursive: true }); }
function exists(file) { try { return fs.existsSync(file); } catch { return false; } }
function readJson(file, fallback) { try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return fallback; } }
function chmodPrivate(file) { try { fs.chmodSync(file, 0o600); } catch {} }
function writeFileAtomic(file, data, mode) {
  mkdirp(path.dirname(file));
  const tmp = `${file}.tmp.${process.pid}`;
  fs.writeFileSync(tmp, data, 'utf8');
  if (mode) { try { fs.chmodSync(tmp, mode); } catch {} }
  fs.renameSync(tmp, file);
  if (mode) chmodPrivate(file);
}
function writeJsonAtomic(file, data, mode) { writeFileAtomic(file, JSON.stringify(data, null, 2) + '\n', mode); }
function timestamp() { return new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14); }
function backup(file) { if (exists(file)) fs.copyFileSync(file, `${file}.backup.${timestamp()}`); }
function mask(value) { if (!value) return '<missing>'; return value.length <= 8 ? '<hidden>' : `${value.slice(0, 4)}...${value.slice(-4)}`; }
function tomlEscape(value) { return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"'); }
function shellEscapeSingle(value) { return String(value).replace(/'/g, "'\\''"); }
function psEscapeSingle(value) { return String(value).replace(/'/g, "''"); }
function normalizeAgents(value) {
  if (!value || value === 'all') return ['codex', 'claudecode', 'openclaw'];
  return value.split(',').map((x) => x.trim()).filter(Boolean).map((x) => {
    if (['claude', 'claude-code'].includes(x)) return 'claudecode';
    if (x === 'claw') return 'openclaw';
    return x;
  });
}
function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const item = argv[i];
    if (!item.startsWith('--')) { args._.push(item); continue; }
    const eq = item.indexOf('=');
    if (eq !== -1) {
      args[item.slice(2, eq)] = item.slice(eq + 1);
    } else {
      const key = item.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith('--')) { args[key] = next; i += 1; }
      else { args[key] = true; }
    }
  }
  return args;
}
function loadStore() {
  const store = readJson(STORE_FILE, { version: 1, profiles: {} });
  store.version = store.version || 1;
  store.profiles = store.profiles || {};
  return store;
}
function saveStore(store) { writeJsonAtomic(STORE_FILE, store, 0o600); }
function profileFromArgs(name, args) {
  const token = args.token || process.env.AGENT_TOKEN || process.env.CODEX_TOKEN || process.env.CLAUDE_TOKEN || process.env.CLAUDE_CLIENT_TOKEN || process.env.OPENCLAW_TOKEN || '';
  const baseUrl = args['base-url'] || args.url || process.env.AGENT_BASE_URL || process.env.CODEX_API_URL || process.env.CLAUDE_API_URL || process.env.OPENCLAW_BASE_URL || '';
  const codexUrl = args['codex-url'] || process.env.CODEX_API_URL || baseUrl;
  const claudeUrl = args['claude-url'] || process.env.CLAUDE_API_URL || baseUrl;
  const openclawUrl = args['openclaw-url'] || process.env.OPENCLAW_BASE_URL || baseUrl;
  if (!token) throw new Error('Missing --token or token env var');
  if (!baseUrl && (!codexUrl || !claudeUrl || !openclawUrl)) throw new Error('Missing --base-url or per-agent URLs');
  return {
    name,
    token,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    codex: {
      baseUrl: codexUrl,
      model: args['codex-model'] || args.model || process.env.CODEX_MODEL || DEFAULTS.codexModel,
      reasoning: args.reasoning || process.env.CODEX_REASONING_EFFORT || DEFAULTS.codexReasoning,
      providerId: args['codex-provider'] || process.env.CODEX_PROVIDER_ID || DEFAULTS.codexProviderId,
      envKey: args['codex-env-key'] || process.env.CODEX_PROVIDER_ENV_KEY || DEFAULTS.codexEnvKey,
    },
    claudecode: {
      baseUrl: claudeUrl,
    },
    openclaw: {
      baseUrl: openclawUrl,
      model: args['openclaw-model'] || process.env.OPENCLAW_MODEL || DEFAULTS.openclawModel,
    },
  };
}
function applyCodex(profile, dryRun) {
  const codexDir = path.join(HOME, '.codex');
  const configFile = path.join(codexDir, 'config.toml');
  const privateEnv = path.join(codexDir, 'private.env');
  const provider = profile.codex.providerId || DEFAULTS.codexProviderId;
  const envKey = profile.codex.envKey || DEFAULTS.codexEnvKey;
  const config = `# Managed by agent-bootstrap switcher.\nmodel = "${tomlEscape(profile.codex.model)}"\nmodel_reasoning_effort = "${tomlEscape(profile.codex.reasoning)}"\npreferred_auth_method = "apikey"\ndisable_response_storage = true\nmodel_provider = "${tomlEscape(provider)}"\n\n[model_providers."${tomlEscape(provider)}"]\nname = "${tomlEscape(provider)}"\nbase_url = "${tomlEscape(profile.codex.baseUrl)}"\nwire_api = "responses"\nenv_key = "${tomlEscape(envKey)}"\n\n[plugins."browser-use@openai-bundled"]\nenabled = true\n`;
  const env = os.platform() === 'win32'
    ? `$env:${envKey} = '${psEscapeSingle(profile.token)}'\n`
    : `export ${envKey}='${shellEscapeSingle(profile.token)}'\n`;
  if (dryRun) { console.log(`[DRY-RUN] write ${configFile}`); console.log(`[DRY-RUN] write ${privateEnv}`); return; }
  mkdirp(codexDir); backup(configFile); writeFileAtomic(configFile, config, 0o600); writeFileAtomic(privateEnv, env, 0o600);
}
function applyClaude(profile, dryRun) {
  const claudeDir = path.join(HOME, '.claude');
  const settingsFile = path.join(claudeDir, 'settings.json');
  const claudeJsonFile = path.join(HOME, '.claude.json');
  const envShFile = path.join(STATE_DIR, 'claude-code-env.sh');
  const envPs1File = path.join(STATE_DIR, 'claude-code-env.ps1');
  const settings = readJson(settingsFile, {});
  settings.env = settings.env || {};
  Object.assign(settings.env, {
    ANTHROPIC_AUTH_TOKEN: profile.token,
    ANTHROPIC_BASE_URL: profile.claudecode.baseUrl,
    API_TIMEOUT_MS: 600000,
    CLAUDE_CODE_DISABLE_TERMINAL_TITLE: '1',
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: '1',
  });
  settings.permissions = settings.permissions || { allow: [], deny: [] };
  const claudeJson = readJson(claudeJsonFile, {});
  claudeJson.hasCompletedOnboarding = true;
  const envSh = `# Managed by agent-bootstrap switcher.\nunset CLAUDE_CODE_OAUTH_TOKEN\nexport ANTHROPIC_AUTH_TOKEN='${shellEscapeSingle(profile.token)}'\nexport ANTHROPIC_BASE_URL='${shellEscapeSingle(profile.claudecode.baseUrl)}'\nexport API_TIMEOUT_MS=600000\nexport CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1\nexport CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1\n`;
  const envPs1 = `# Managed by agent-bootstrap switcher.\nRemove-Item Env:CLAUDE_CODE_OAUTH_TOKEN -ErrorAction SilentlyContinue\n$env:ANTHROPIC_AUTH_TOKEN = '${psEscapeSingle(profile.token)}'\n$env:ANTHROPIC_BASE_URL = '${psEscapeSingle(profile.claudecode.baseUrl)}'\n$env:API_TIMEOUT_MS = '600000'\n$env:CLAUDE_CODE_DISABLE_TERMINAL_TITLE = '1'\n$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'\n`;
  if (dryRun) { console.log(`[DRY-RUN] write ${settingsFile}`); console.log(`[DRY-RUN] write ${claudeJsonFile}`); console.log(`[DRY-RUN] write ${envShFile}`); console.log(`[DRY-RUN] write ${envPs1File}`); return; }
  mkdirp(claudeDir); backup(settingsFile); backup(claudeJsonFile); writeJsonAtomic(settingsFile, settings, 0o600); writeJsonAtomic(claudeJsonFile, claudeJson, 0o600);
  writeFileAtomic(envShFile, envSh, 0o600);
  writeFileAtomic(envPs1File, envPs1, 0o600);
}
function applyOpenClaw(profile, dryRun) {
  const configDir = process.env.OPENCLAW_CONFIG_DIR || path.join(HOME, '.openclaw');
  const configPath = path.join(configDir, 'openclaw.json');
  const authPath = path.join(configDir, 'agents', 'main', 'agent', 'auth-profiles.json');
  const cleanBase = profile.openclaw.baseUrl.replace(/\/+$/, '');
  const config = Object.assign({}, readJson(configPath, {}));
  config.models = { mode: 'merge', providers: {
    openai: { baseUrl: `${cleanBase}/v1`, models: [] },
    anthropic: { baseUrl: cleanBase, models: [] },
    google: { baseUrl: `${cleanBase}/v1beta`, models: [] },
  } };
  config.agents = { defaults: { model: { primary: profile.openclaw.model }, models: { [profile.openclaw.model]: {} } } };
  config.meta = Object.assign({}, config.meta || {}, { managedBy: 'agent-bootstrap', lastTouchedAt: new Date().toISOString() });
  const auth = { version: 1, profiles: {
    'openai:default': { type: 'api_key', provider: 'openai', key: profile.token },
    'anthropic:default': { type: 'api_key', provider: 'anthropic', key: profile.token },
    'google:default': { type: 'api_key', provider: 'google', key: profile.token },
  } };
  if (dryRun) { console.log(`[DRY-RUN] write ${configPath}`); console.log(`[DRY-RUN] write ${authPath}`); return; }
  backup(configPath); backup(authPath); writeJsonAtomic(configPath, config, 0o600); writeJsonAtomic(authPath, auth, 0o600);
}
function usage() {
  console.log(`Agent Switch\n\nCommands:\n  add <name> --token TOKEN --base-url URL [--model MODEL]\n  list\n  current\n  use <name> [--agents codex,claudecode,openclaw] [--dry-run]\n  remove <name>\n  shell-hook\n  doctor\n\nExamples:\n  node switch.js add sss --token ... --base-url https://node-hk.sssaicode.com/api\n  node switch.js use sss --agents codex,claudecode,openclaw\n`);
}
function main() {
  const argv = process.argv.slice(2);
  const command = argv[0];
  const args = parseArgs(argv.slice(1));
  try {
    if (!command || command === 'help' || command === '--help' || command === '-h') { usage(); return; }
    const store = loadStore();
    if (command === 'add') {
      const name = args._[0];
      if (!name) throw new Error('Missing profile name');
      const existing = store.profiles[name];
      const profile = profileFromArgs(name, args);
      if (existing && existing.createdAt) profile.createdAt = existing.createdAt;
      store.profiles[name] = profile;
      saveStore(store);
      console.log(`[OK] saved profile ${name} with token ${mask(profile.token)}`);
      return;
    }
    if (command === 'list') {
      const names = Object.keys(store.profiles);
      if (!names.length) { console.log('No profiles yet.'); return; }
      names.forEach((name) => {
        const p = store.profiles[name];
        console.log(`${name}\t${p.codex?.baseUrl || ''}\t${mask(p.token || '')}`);
      });
      return;
    }
    if (command === 'current') { console.log(JSON.stringify(readJson(CURRENT_FILE, {}), null, 2)); return; }
    if (command === 'shell-hook') {
      if (os.platform() === 'win32') console.log(`. \"${path.join(STATE_DIR, 'claude-code-env.ps1')}\"`);
      else console.log(`[ -f \"${path.join(STATE_DIR, 'claude-code-env.sh')}\" ] && . \"${path.join(STATE_DIR, 'claude-code-env.sh')}\"`);
      return;
    }
    if (command === 'remove') {
      const name = args._[0];
      if (!name) throw new Error('Missing profile name');
      delete store.profiles[name]; saveStore(store); console.log(`[OK] removed ${name}`); return;
    }
    if (command === 'use') {
      const name = args._[0];
      if (!name) throw new Error('Missing profile name');
      const profile = store.profiles[name];
      if (!profile) throw new Error(`Unknown profile: ${name}`);
      const agents = normalizeAgents(args.agents || 'all');
      const dryRun = Boolean(args['dry-run']);
      agents.forEach((agent) => {
        if (agent === 'codex') applyCodex(profile, dryRun);
        else if (agent === 'claudecode') applyClaude(profile, dryRun);
        else if (agent === 'openclaw') applyOpenClaw(profile, dryRun);
        else throw new Error(`Unknown agent: ${agent}`);
        console.log(`[OK] applied ${name} to ${agent}`);
      });
      if (!dryRun) writeJsonAtomic(CURRENT_FILE, { profile: name, agents, updatedAt: new Date().toISOString() }, 0o600);
      return;
    }
    if (command === 'doctor') {
      console.log(`stateDir=${STATE_DIR}`);
      console.log(`profiles=${Object.keys(store.profiles).length}`);
      ['.codex/config.toml', '.claude/settings.json', '.openclaw/openclaw.json'].forEach((rel) => console.log(`${rel}=${exists(path.join(HOME, rel)) ? 'present' : 'missing'}`));
      if (process.env.CLAUDE_CODE_OAUTH_TOKEN) console.log('warning=CLAUDE_CODE_OAUTH_TOKEN is set and may override Claude Code API-token settings. Run `node switch.js shell-hook` and source the printed file.');
      return;
    }
    throw new Error(`Unknown command: ${command}`);
  } catch (err) {
    console.error(`[ERROR] ${err.message}`);
    process.exit(1);
  }
}

main();
