#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const HOME = os.homedir();
const STATE_DIR = process.env.AGENT_BOOTSTRAP_HOME || path.join(HOME, '.agent-bootstrap');
const STORE_FILE = path.join(STATE_DIR, 'profiles.json');
const CURRENT_FILE = path.join(STATE_DIR, 'current.json');
const BACKUP_DIR = path.join(STATE_DIR, 'backups');

const DEFAULTS = {
  codexModel: 'gpt-5.5',
  codexReasoning: 'high',
  codexProviderId: 'custom',
  codexEnvKey: 'CODEX_API_KEY',
  claudeTimeoutMs: 600000,
  openclawModel: 'anthropic/claude-opus-4-7',
};

const PRESETS = {
  sssaicode: {
    label: 'SSSAI Code gateway',
    baseUrl: 'https://node-hk.sssaicode.com/api',
    codexUrl: 'https://codex1.sssaicode.com/api/v1',
    claudeUrl: 'https://node-hk.sssaicode.com/api',
    openclawUrl: 'https://node-hk.sssaicode.com/api',
    openclawModel: DEFAULTS.openclawModel,
  },
  custom: {
    label: 'Bring your own OpenAI/Anthropic-compatible gateway',
  },
};

const AGENT_LABELS = {
  codex: 'Codex',
  claudecode: 'Claude Code',
  openclaw: 'OpenClaw',
};

const COLOR_ENABLED = process.env.NO_COLOR !== '1' && process.env.NO_COLOR !== 'true' && process.stdout.isTTY;
const C = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m', blue: '\x1b[34m', cyan: '\x1b[36m', magenta: '\x1b[35m',
};
function color(name, text) { return COLOR_ENABLED ? `${C[name]}${text}${C.reset}` : text; }
function ok(message) { console.log(`${color('green', '[OK]')} ${message}`); }
function info(message) { console.log(`${color('blue', '[INFO]')} ${message}`); }
function warn(message) { console.log(`${color('yellow', '[WARN]')} ${message}`); }
function failLine(message) { console.log(`${color('red', '[FAIL]')} ${message}`); }
function step(message) { console.log(`\n${color('magenta', '==>')} ${color('bold', message)}`); }

function mkdirp(dir) { fs.mkdirSync(dir, { recursive: true }); }
function exists(file) { try { return fs.existsSync(file); } catch { return false; } }
function readText(file, fallback = '') { try { return fs.readFileSync(file, 'utf8'); } catch { return fallback; } }
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
function mask(value) { if (!value) return '<missing>'; return value.length <= 8 ? '<hidden>' : `${value.slice(0, 4)}...${value.slice(-4)}`; }
function tomlEscape(value) { return String(value ?? '').replace(/\\/g, '\\\\').replace(/"/g, '\\"'); }
function shellEscapeSingle(value) { return String(value ?? '').replace(/'/g, "'\\''"); }
function psEscapeSingle(value) { return String(value ?? '').replace(/'/g, "''"); }
function safeName(value) { return String(value).replace(/[^a-zA-Z0-9._-]/g, '_'); }
function parseTomlString(text, key) {
  const re = new RegExp(`^\\s*${key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*=\\s*"((?:\\\\.|[^"])*)"`, 'm');
  const match = text.match(re);
  if (!match) return '';
  return match[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\');
}
function parseEnvValue(text, key) {
  if (!key) return '';
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const patterns = [
    new RegExp(`^\\s*export\\s+${escaped}=(['"])(.*?)\\1`, 'm'),
    new RegExp(`^\\s*${escaped}=(['"])(.*?)\\1`, 'm'),
    new RegExp(`^\\s*\\$env:${escaped}\\s*=\\s*(['"])(.*?)\\1`, 'm'),
  ];
  for (const re of patterns) {
    const match = text.match(re);
    if (match) return match[2].replace(/'\\''/g, "'").replace(/''/g, "'");
  }
  return '';
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

function normalizeAgentName(name) {
  const value = String(name || '').toLowerCase();
  if (['claude', 'claude-code', 'claudecode', 'cc'].includes(value)) return 'claudecode';
  if (['claw', 'open-claw', 'openclaw'].includes(value)) return 'openclaw';
  if (['codex', 'openai-codex'].includes(value)) return 'codex';
  return value;
}
function normalizeAgents(value) {
  if (!value || value === 'all') return ['codex', 'claudecode', 'openclaw'];
  const agents = String(value).split(',').map((x) => normalizeAgentName(x.trim())).filter(Boolean);
  return [...new Set(agents)];
}
function envToken(agent) {
  if (agent === 'codex') return process.env.CODEX_TOKEN || process.env.CODEX_API_KEY || '';
  if (agent === 'claudecode') return process.env.CLAUDE_TOKEN || process.env.CLAUDE_CLIENT_TOKEN || process.env.ANTHROPIC_AUTH_TOKEN || '';
  if (agent === 'openclaw') return process.env.OPENCLAW_TOKEN || '';
  return '';
}
function sharedToken(args) {
  return args.token || process.env.AGENT_TOKEN || process.env.CODEX_TOKEN || process.env.CLAUDE_TOKEN || process.env.CLAUDE_CLIENT_TOKEN || process.env.OPENCLAW_TOKEN || '';
}
function resolvePreset(args) {
  const name = String(args.preset || args.provider || 'custom').toLowerCase();
  const preset = PRESETS[name];
  if (!preset) throw new Error(`Unknown preset: ${name}. Run \`preset list\`.`);
  return { name, preset };
}

function migrateStore(store) {
  const next = store && typeof store === 'object' ? store : {};
  next.version = 2;
  next.profiles = next.profiles && typeof next.profiles === 'object' ? next.profiles : {};
  for (const [name, profile] of Object.entries(next.profiles)) {
    profile.name = profile.name || name;
    profile.createdAt = profile.createdAt || new Date().toISOString();
    profile.updatedAt = profile.updatedAt || profile.createdAt;
    profile.preset = profile.preset || 'custom';
    profile.codex = profile.codex || {};
    profile.claudecode = profile.claudecode || {};
    profile.openclaw = profile.openclaw || {};
  }
  return next;
}
function loadStore() { return migrateStore(readJson(STORE_FILE, { version: 2, profiles: {} })); }
function saveStore(store) { saveStoreWithMode(store, 0o600); }
function saveStoreWithMode(store, mode) { writeJsonAtomic(STORE_FILE, migrateStore(store), mode); }
function currentState() { return readJson(CURRENT_FILE, {}); }
function isRedacted(value) { return value === '<redacted>' || value === 'REDACTED' || value === ''; }
function agentToken(profile, agent) {
  const section = profile[agent] || {};
  return section.token || profile.token || '';
}
function profileSummary(profile) {
  return {
    name: profile.name,
    preset: profile.preset || 'custom',
    token: mask(profile.token || agentToken(profile, 'codex') || agentToken(profile, 'claudecode') || agentToken(profile, 'openclaw')),
    codex: profile.codex?.baseUrl || '',
    claudecode: profile.claudecode?.baseUrl || '',
    openclaw: profile.openclaw?.baseUrl || '',
  };
}
function profileFromArgs(name, args, existing = {}) {
  const { name: presetName, preset } = resolvePreset(args);
  const token = sharedToken(args) || existing.token || '';
  const baseUrl = args['base-url'] || args.url || process.env.AGENT_BASE_URL || preset.baseUrl || '';
  const codexUrl = args['codex-url'] || process.env.CODEX_API_URL || existing.codex?.baseUrl || preset.codexUrl || baseUrl;
  const claudeUrl = args['claude-url'] || process.env.CLAUDE_API_URL || existing.claudecode?.baseUrl || preset.claudeUrl || baseUrl;
  const openclawUrl = args['openclaw-url'] || process.env.OPENCLAW_BASE_URL || existing.openclaw?.baseUrl || preset.openclawUrl || baseUrl;
  const codexToken = args['codex-token'] || envToken('codex') || existing.codex?.token || token;
  const claudeToken = args['claude-token'] || envToken('claudecode') || existing.claudecode?.token || token;
  const openclawToken = args['openclaw-token'] || envToken('openclaw') || existing.openclaw?.token || token;
  if (!token && !codexToken && !claudeToken && !openclawToken) throw new Error('Missing --token or token env var');
  if (!codexUrl || !claudeUrl || !openclawUrl) throw new Error('Missing --base-url or per-agent URLs');
  const now = new Date().toISOString();
  return {
    name,
    preset: presetName,
    token,
    createdAt: existing.createdAt || now,
    updatedAt: now,
    codex: {
      token: codexToken && codexToken !== token ? codexToken : undefined,
      baseUrl: codexUrl,
      model: args['codex-model'] || args.model || process.env.CODEX_MODEL || existing.codex?.model || DEFAULTS.codexModel,
      reasoning: args.reasoning || process.env.CODEX_REASONING_EFFORT || existing.codex?.reasoning || DEFAULTS.codexReasoning,
      providerId: args['codex-provider'] || process.env.CODEX_PROVIDER_ID || existing.codex?.providerId || DEFAULTS.codexProviderId,
      envKey: args['codex-env-key'] || process.env.CODEX_PROVIDER_ENV_KEY || existing.codex?.envKey || DEFAULTS.codexEnvKey,
    },
    claudecode: {
      token: claudeToken && claudeToken !== token ? claudeToken : undefined,
      baseUrl: claudeUrl,
      timeoutMs: Number(args['claude-timeout-ms'] || existing.claudecode?.timeoutMs || DEFAULTS.claudeTimeoutMs),
    },
    openclaw: {
      token: openclawToken && openclawToken !== token ? openclawToken : undefined,
      baseUrl: openclawUrl,
      model: args['openclaw-model'] || process.env.OPENCLAW_MODEL || existing.openclaw?.model || preset.openclawModel || DEFAULTS.openclawModel,
    },
  };
}

function targetFilesForAgents(agents) {
  const files = [];
  if (agents.includes('codex')) {
    files.push(path.join(HOME, '.codex', 'config.toml'));
    files.push(path.join(HOME, '.codex', 'private.env'));
  }
  if (agents.includes('claudecode')) {
    files.push(path.join(HOME, '.claude', 'settings.json'));
    files.push(path.join(HOME, '.claude.json'));
    files.push(path.join(STATE_DIR, 'claude-code-env.sh'));
    files.push(path.join(STATE_DIR, 'claude-code-env.ps1'));
  }
  if (agents.includes('openclaw')) {
    const configDir = process.env.OPENCLAW_CONFIG_DIR || path.join(HOME, '.openclaw');
    files.push(path.join(configDir, 'openclaw.json'));
    files.push(path.join(configDir, 'agents', 'main', 'agent', 'auth-profiles.json'));
  }
  return files;
}
function createBackupSet(files, label, dryRun) {
  const id = timestamp();
  const dir = path.join(BACKUP_DIR, id);
  const manifest = { id, label, createdAt: new Date().toISOString(), files: [] };
  for (const target of [...new Set(files)]) {
    const existed = exists(target);
    const backupName = `${String(manifest.files.length + 1).padStart(2, '0')}-${safeName(path.basename(target))}`;
    const backupPath = path.join(dir, backupName);
    manifest.files.push({ target, existed, backup: existed ? backupPath : null });
    if (dryRun) continue;
    if (existed) {
      mkdirp(dir);
      fs.copyFileSync(target, backupPath);
      chmodPrivate(backupPath);
    }
  }
  if (!dryRun) {
    mkdirp(dir);
    writeJsonAtomic(path.join(dir, 'manifest.json'), manifest, 0o600);
  }
  return manifest;
}
function listBackups() {
  if (!exists(BACKUP_DIR)) return [];
  return fs.readdirSync(BACKUP_DIR).map((id) => readJson(path.join(BACKUP_DIR, id, 'manifest.json'), null)).filter(Boolean).sort((a, b) => b.id.localeCompare(a.id));
}
function restoreBackup(id, dryRun) {
  const backups = listBackups();
  const selected = id === 'latest' ? backups[0] : backups.find((item) => item.id === id);
  if (!selected) throw new Error(`Backup not found: ${id}`);
  step(`Restore backup ${selected.id}`);
  selected.files.forEach((entry) => {
    if (dryRun) { console.log(`[DRY-RUN] restore ${entry.target}`); return; }
    mkdirp(path.dirname(entry.target));
    if (entry.existed && entry.backup && exists(entry.backup)) {
      fs.copyFileSync(entry.backup, entry.target);
      chmodPrivate(entry.target);
    } else if (!entry.existed && exists(entry.target)) {
      fs.rmSync(entry.target, { force: true });
    }
    ok(`restored ${entry.target}`);
  });
}

function buildCodexConfig(profile) {
  const provider = profile.codex.providerId || DEFAULTS.codexProviderId;
  const envKey = profile.codex.envKey || DEFAULTS.codexEnvKey;
  return `# Managed by agent-bootstrap switcher.\nmodel = "${tomlEscape(profile.codex.model || DEFAULTS.codexModel)}"\nmodel_reasoning_effort = "${tomlEscape(profile.codex.reasoning || DEFAULTS.codexReasoning)}"\npreferred_auth_method = "apikey"\ndisable_response_storage = true\nmodel_provider = "${tomlEscape(provider)}"\napproval_policy = "never"\nsandbox_mode = "danger-full-access"\n\n[model_providers."${tomlEscape(provider)}"]\nname = "${tomlEscape(provider)}"\nbase_url = "${tomlEscape(profile.codex.baseUrl)}"\nwire_api = "responses"\nenv_key = "${tomlEscape(envKey)}"\n\n[plugins."browser-use@openai-bundled"]\nenabled = true\n`;
}
function applyCodex(profile, dryRun) {
  const codexDir = path.join(HOME, '.codex');
  const configFile = path.join(codexDir, 'config.toml');
  const privateEnv = path.join(codexDir, 'private.env');
  const envKey = profile.codex.envKey || DEFAULTS.codexEnvKey;
  const token = agentToken(profile, 'codex');
  if (!token || isRedacted(token)) throw new Error('Codex token is missing or redacted');
  const config = buildCodexConfig(profile);
  const env = os.platform() === 'win32'
    ? `$env:${envKey} = '${psEscapeSingle(token)}'\n`
    : `export ${envKey}='${shellEscapeSingle(token)}'\n`;
  if (dryRun) { console.log(`[DRY-RUN] write ${configFile}`); console.log(`[DRY-RUN] write ${privateEnv}`); return; }
  mkdirp(codexDir);
  writeFileAtomic(configFile, config, 0o600);
  writeFileAtomic(privateEnv, env, 0o600);
}
function applyClaude(profile, dryRun) {
  const claudeDir = path.join(HOME, '.claude');
  const settingsFile = path.join(claudeDir, 'settings.json');
  const claudeJsonFile = path.join(HOME, '.claude.json');
  const envShFile = path.join(STATE_DIR, 'claude-code-env.sh');
  const envPs1File = path.join(STATE_DIR, 'claude-code-env.ps1');
  const token = agentToken(profile, 'claudecode');
  if (!token || isRedacted(token)) throw new Error('Claude Code token is missing or redacted');
  const settings = readJson(settingsFile, {});
  settings.env = settings.env || {};
  Object.assign(settings.env, {
    ANTHROPIC_AUTH_TOKEN: token,
    ANTHROPIC_BASE_URL: profile.claudecode.baseUrl,
    API_TIMEOUT_MS: profile.claudecode.timeoutMs || DEFAULTS.claudeTimeoutMs,
    CLAUDE_CODE_DISABLE_TERMINAL_TITLE: '1',
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: '1',
  });
  settings.permissions = settings.permissions || { allow: [], deny: [] };
  const claudeJson = readJson(claudeJsonFile, {});
  claudeJson.hasCompletedOnboarding = true;
  const envSh = `# Managed by agent-bootstrap switcher.\nunset CLAUDE_CODE_OAUTH_TOKEN\nexport ANTHROPIC_AUTH_TOKEN='${shellEscapeSingle(token)}'\nexport ANTHROPIC_BASE_URL='${shellEscapeSingle(profile.claudecode.baseUrl)}'\nexport API_TIMEOUT_MS=${profile.claudecode.timeoutMs || DEFAULTS.claudeTimeoutMs}\nexport CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1\nexport CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1\n`;
  const envPs1 = `# Managed by agent-bootstrap switcher.\nRemove-Item Env:CLAUDE_CODE_OAUTH_TOKEN -ErrorAction SilentlyContinue\n$env:ANTHROPIC_AUTH_TOKEN = '${psEscapeSingle(token)}'\n$env:ANTHROPIC_BASE_URL = '${psEscapeSingle(profile.claudecode.baseUrl)}'\n$env:API_TIMEOUT_MS = '${profile.claudecode.timeoutMs || DEFAULTS.claudeTimeoutMs}'\n$env:CLAUDE_CODE_DISABLE_TERMINAL_TITLE = '1'\n$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'\n`;
  if (dryRun) { console.log(`[DRY-RUN] write ${settingsFile}`); console.log(`[DRY-RUN] write ${claudeJsonFile}`); console.log(`[DRY-RUN] write ${envShFile}`); console.log(`[DRY-RUN] write ${envPs1File}`); return; }
  mkdirp(claudeDir);
  writeJsonAtomic(settingsFile, settings, 0o600);
  writeJsonAtomic(claudeJsonFile, claudeJson, 0o600);
  writeFileAtomic(envShFile, envSh, 0o600);
  writeFileAtomic(envPs1File, envPs1, 0o600);
}
function applyOpenClaw(profile, dryRun) {
  const configDir = process.env.OPENCLAW_CONFIG_DIR || path.join(HOME, '.openclaw');
  const configPath = path.join(configDir, 'openclaw.json');
  const authPath = path.join(configDir, 'agents', 'main', 'agent', 'auth-profiles.json');
  const token = agentToken(profile, 'openclaw');
  if (!token || isRedacted(token)) throw new Error('OpenClaw token is missing or redacted');
  const cleanBase = String(profile.openclaw.baseUrl || '').replace(/\/+$/, '');
  const config = Object.assign({}, readJson(configPath, {}));
  config.models = { mode: 'merge', providers: {
    openai: { baseUrl: `${cleanBase}/v1`, models: [] },
    anthropic: { baseUrl: cleanBase, models: [] },
    google: { baseUrl: `${cleanBase}/v1beta`, models: [] },
  } };
  config.agents = { defaults: { model: { primary: profile.openclaw.model || DEFAULTS.openclawModel }, models: { [profile.openclaw.model || DEFAULTS.openclawModel]: {} } } };
  config.meta = Object.assign({}, config.meta || {}, { managedBy: 'agent-bootstrap', lastTouchedAt: new Date().toISOString() });
  const auth = { version: 1, profiles: {
    'openai:default': { type: 'api_key', provider: 'openai', key: token },
    'anthropic:default': { type: 'api_key', provider: 'anthropic', key: token },
    'google:default': { type: 'api_key', provider: 'google', key: token },
  } };
  if (dryRun) { console.log(`[DRY-RUN] write ${configPath}`); console.log(`[DRY-RUN] write ${authPath}`); return; }
  writeJsonAtomic(configPath, config, 0o600);
  writeJsonAtomic(authPath, auth, 0o600);
}

function captureProfile(name, args) {
  const codexConfig = readText(path.join(HOME, '.codex', 'config.toml'));
  const codexEnvKey = parseTomlString(codexConfig, 'env_key') || DEFAULTS.codexEnvKey;
  const codexPrivate = readText(path.join(HOME, '.codex', 'private.env'));
  const claudeSettings = readJson(path.join(HOME, '.claude', 'settings.json'), {});
  const openclawDir = process.env.OPENCLAW_CONFIG_DIR || path.join(HOME, '.openclaw');
  const openclawConfig = readJson(path.join(openclawDir, 'openclaw.json'), {});
  const openclawAuth = readJson(path.join(openclawDir, 'agents', 'main', 'agent', 'auth-profiles.json'), {});
  const codexToken = args['codex-token'] || envToken('codex') || parseEnvValue(codexPrivate, codexEnvKey);
  const claudeToken = args['claude-token'] || envToken('claudecode') || claudeSettings.env?.ANTHROPIC_AUTH_TOKEN || '';
  const openclawToken = args['openclaw-token'] || envToken('openclaw') || openclawAuth.profiles?.['anthropic:default']?.key || openclawAuth.profiles?.['openai:default']?.key || '';
  const token = sharedToken(args) || codexToken || claudeToken || openclawToken;
  if (!token && !args['allow-missing-token']) throw new Error('Could not capture a token. Pass --token or --allow-missing-token.');
  const now = new Date().toISOString();
  return {
    name,
    preset: 'captured',
    token,
    createdAt: now,
    updatedAt: now,
    codex: {
      token: codexToken && codexToken !== token ? codexToken : undefined,
      baseUrl: args['codex-url'] || parseTomlString(codexConfig, 'base_url') || '',
      model: args['codex-model'] || parseTomlString(codexConfig, 'model') || DEFAULTS.codexModel,
      reasoning: args.reasoning || parseTomlString(codexConfig, 'model_reasoning_effort') || DEFAULTS.codexReasoning,
      providerId: args['codex-provider'] || parseTomlString(codexConfig, 'model_provider') || DEFAULTS.codexProviderId,
      envKey: args['codex-env-key'] || codexEnvKey,
    },
    claudecode: {
      token: claudeToken && claudeToken !== token ? claudeToken : undefined,
      baseUrl: args['claude-url'] || claudeSettings.env?.ANTHROPIC_BASE_URL || '',
      timeoutMs: Number(claudeSettings.env?.API_TIMEOUT_MS || DEFAULTS.claudeTimeoutMs),
    },
    openclaw: {
      token: openclawToken && openclawToken !== token ? openclawToken : undefined,
      baseUrl: args['openclaw-url'] || openclawConfig.models?.providers?.anthropic?.baseUrl || '',
      model: args['openclaw-model'] || openclawConfig.agents?.defaults?.model?.primary || DEFAULTS.openclawModel,
    },
  };
}

function redactProfile(profile) {
  const copy = JSON.parse(JSON.stringify(profile));
  if (copy.token) copy.token = '<redacted>';
  ['codex', 'claudecode', 'openclaw'].forEach((agent) => { if (copy[agent]?.token) copy[agent].token = '<redacted>'; });
  return copy;
}
function exportStore(store, includeSecrets) {
  const payload = migrateStore(JSON.parse(JSON.stringify(store)));
  payload.exportedAt = new Date().toISOString();
  if (!includeSecrets) {
    for (const name of Object.keys(payload.profiles)) payload.profiles[name] = redactProfile(payload.profiles[name]);
  }
  return payload;
}
function importStore(file, args, store) {
  const payload = readJson(file, null);
  if (!payload || !payload.profiles) throw new Error(`Invalid profile export: ${file}`);
  const imported = migrateStore(payload);
  if (args.replace) store.profiles = {};
  for (const [name, profile] of Object.entries(imported.profiles)) {
    if (store.profiles[name] && !args.force && !args.replace) throw new Error(`Profile already exists: ${name}. Use --force or --replace.`);
    store.profiles[name] = profile;
  }
  saveStore(store);
  ok(`imported ${Object.keys(imported.profiles).length} profile(s)`);
}

function shellHookLine() {
  if (os.platform() === 'win32') return `. "${path.join(STATE_DIR, 'claude-code-env.ps1')}"`;
  return `[ -f "${path.join(STATE_DIR, 'claude-code-env.sh')}" ] && . "${path.join(STATE_DIR, 'claude-code-env.sh')}"`;
}
function detectShellRc() {
  if (process.env.AGENT_SWITCH_RC) return process.env.AGENT_SWITCH_RC;
  const shell = process.env.SHELL || '';
  if (shell.includes('zsh')) return path.join(HOME, '.zshrc');
  if (shell.includes('bash')) return os.platform() === 'darwin' ? path.join(HOME, '.bash_profile') : path.join(HOME, '.bashrc');
  return path.join(HOME, '.profile');
}
function installShellHook(args) {
  const target = args.target || detectShellRc();
  const line = shellHookLine();
  const marker = '# Agent Bootstrap Claude Code env';
  if (os.platform() === 'win32') {
    warn('On Windows, add the printed shell hook to your PowerShell profile manually.');
    console.log(line);
    return;
  }
  const current = readText(target);
  if (current.includes(line)) { ok(`shell hook already installed: ${target}`); return; }
  writeFileAtomic(target, `${current.replace(/\s*$/, '\n')}\n${marker}\n${line}\n`, 0o600);
  ok(`shell hook installed: ${target}`);
}

function usage() {
  console.log(`${color('bold', 'Agent Switch')}\n\nCommands:\n  preset list\n  add <name> --token TOKEN (--preset sssaicode | --base-url URL)\n  update <name> [same options as add]\n  capture <name> [--token TOKEN]\n  list [--json]\n  show <name> [--json]\n  current\n  use <name> [--agents codex,claudecode,openclaw] [--dry-run]\n  remove <name> [--force]\n  export [file] [--include-secrets]\n  import <file> [--force|--replace]\n  backups\n  restore <id|latest> [--dry-run]\n  shell-hook [--install] [--target FILE]\n  doctor [--strict]\n\nExamples:\n  node switch.js add sss --preset sssaicode --token YOUR_TOKEN\n  node switch.js use sss\n  node switch.js capture current-local\n  node switch.js export profiles.safe.json\n`);
}

function commandPreset(args) {
  const sub = args._[0] || 'list';
  if (sub !== 'list') throw new Error(`Unknown preset command: ${sub}`);
  Object.entries(PRESETS).forEach(([name, preset]) => {
    console.log(`${name}\t${preset.label || ''}\t${preset.baseUrl || ''}`);
  });
}
function commandList(store, args) {
  const names = Object.keys(store.profiles).sort();
  if (args.json) { console.log(JSON.stringify(names.map((name) => profileSummary(store.profiles[name])), null, 2)); return; }
  if (!names.length) { info('No profiles yet.'); return; }
  const current = currentState().profile;
  console.log(['ACTIVE', 'NAME', 'PRESET', 'CODEX_URL', 'TOKEN'].join('\t'));
  names.forEach((name) => {
    const p = store.profiles[name];
    const marker = name === current ? '*' : '';
    console.log([marker, name, p.preset || 'custom', p.codex?.baseUrl || '', mask(p.token || agentToken(p, 'codex') || '')].join('\t'));
  });
}
function commandShow(store, name, args) {
  const profile = store.profiles[name];
  if (!profile) throw new Error(`Unknown profile: ${name}`);
  const safe = args['include-secrets'] ? profile : redactProfile(profile);
  if (args.json || true) console.log(JSON.stringify(safe, null, 2));
}
function commandUse(store, name, args) {
  const profile = store.profiles[name];
  if (!profile) throw new Error(`Unknown profile: ${name}`);
  const agents = normalizeAgents(args.agents || 'all');
  const dryRun = Boolean(args['dry-run']);
  const unknown = agents.filter((agent) => !AGENT_LABELS[agent]);
  if (unknown.length) throw new Error(`Unknown agent(s): ${unknown.join(', ')}`);
  step(`Apply profile ${name}`);
  const backup = createBackupSet(targetFilesForAgents(agents), `use:${name}:${agents.join(',')}`, dryRun);
  if (dryRun) info(`Would create backup set ${backup.id}`);
  agents.forEach((agent) => {
    if (agent === 'codex') applyCodex(profile, dryRun);
    else if (agent === 'claudecode') applyClaude(profile, dryRun);
    else if (agent === 'openclaw') applyOpenClaw(profile, dryRun);
    ok(`applied ${AGENT_LABELS[agent]}`);
  });
  if (!dryRun) writeJsonAtomic(CURRENT_FILE, { profile: name, agents, backup: backup.id, updatedAt: new Date().toISOString() }, 0o600);
  if (agents.includes('claudecode')) info(`Claude shell hook: ${shellHookLine()}`);
}
function commandDoctor(store, args) {
  const issues = [];
  step('Agent Bootstrap doctor');
  info(`stateDir=${STATE_DIR}`);
  info(`node=${process.version}`);
  info(`profiles=${Object.keys(store.profiles).length}`);
  const checks = [
    ['Codex config', path.join(HOME, '.codex', 'config.toml')],
    ['Codex private env', path.join(HOME, '.codex', 'private.env')],
    ['Claude settings', path.join(HOME, '.claude', 'settings.json')],
    ['Claude env helper', path.join(STATE_DIR, 'claude-code-env.sh')],
    ['OpenClaw config', path.join(process.env.OPENCLAW_CONFIG_DIR || path.join(HOME, '.openclaw'), 'openclaw.json')],
  ];
  checks.forEach(([label, file]) => (exists(file) ? ok(`${label}: ${file}`) : warn(`${label}: missing (${file})`)));
  if (process.env.CLAUDE_CODE_OAUTH_TOKEN) {
    issues.push('CLAUDE_CODE_OAUTH_TOKEN is set and may override API-token based Claude Code settings.');
    warn(issues[issues.length - 1]);
  }
  for (const [name, profile] of Object.entries(store.profiles)) {
    ['codex', 'claudecode', 'openclaw'].forEach((agent) => {
      if (!agentToken(profile, agent)) issues.push(`${name}: missing ${agent} token`);
      if (!profile[agent]?.baseUrl) issues.push(`${name}: missing ${agent} baseUrl`);
    });
  }
  if (!issues.length) ok('No blocking profile issues found.');
  else issues.forEach((issue) => failLine(issue));
  if (args.strict && issues.length) process.exit(2);
}

function main() {
  const argv = process.argv.slice(2);
  const command = argv[0];
  const args = parseArgs(argv.slice(1));
  try {
    if (!command || command === 'help' || command === '--help' || command === '-h') { usage(); return; }
    const store = loadStore();
    if (command === 'preset' || command === 'presets') { commandPreset(args); return; }
    if (command === 'add' || command === 'update') {
      const name = args._[0];
      if (!name) throw new Error('Missing profile name');
      const existing = store.profiles[name] || {};
      if (command === 'add' && existing.name && !args.force) throw new Error(`Profile already exists: ${name}. Use update or --force.`);
      store.profiles[name] = profileFromArgs(name, args, existing);
      saveStore(store);
      ok(`saved profile ${name} (${store.profiles[name].preset}) with token ${mask(store.profiles[name].token || agentToken(store.profiles[name], 'codex'))}`);
      return;
    }
    if (command === 'capture' || command === 'import-current') {
      const name = args._[0];
      if (!name) throw new Error('Missing profile name');
      if (store.profiles[name] && !args.force) throw new Error(`Profile already exists: ${name}. Use --force.`);
      store.profiles[name] = captureProfile(name, args);
      saveStore(store);
      ok(`captured profile ${name} from local agent configs`);
      return;
    }
    if (command === 'list' || command === 'ls') { commandList(store, args); return; }
    if (command === 'show') { commandShow(store, args._[0], args); return; }
    if (command === 'current') { console.log(JSON.stringify(currentState(), null, 2)); return; }
    if (command === 'use' || command === 'switch') { const name = args._[0]; if (!name) throw new Error('Missing profile name'); commandUse(store, name, args); return; }
    if (command === 'remove' || command === 'rm') {
      const name = args._[0];
      if (!name) throw new Error('Missing profile name');
      if (!store.profiles[name]) throw new Error(`Unknown profile: ${name}`);
      if (currentState().profile === name && !args.force) throw new Error('Refusing to remove active profile. Use --force.');
      delete store.profiles[name];
      saveStore(store);
      ok(`removed profile ${name}`);
      return;
    }
    if (command === 'copy') {
      const [from, to] = args._;
      if (!from || !to) throw new Error('Usage: copy <from> <to>');
      if (!store.profiles[from]) throw new Error(`Unknown profile: ${from}`);
      if (store.profiles[to] && !args.force) throw new Error(`Profile already exists: ${to}. Use --force.`);
      store.profiles[to] = JSON.parse(JSON.stringify(store.profiles[from]));
      store.profiles[to].name = to;
      store.profiles[to].createdAt = new Date().toISOString();
      store.profiles[to].updatedAt = store.profiles[to].createdAt;
      saveStore(store);
      ok(`copied ${from} -> ${to}`);
      return;
    }
    if (command === 'rename' || command === 'mv') {
      const [from, to] = args._;
      if (!from || !to) throw new Error('Usage: rename <from> <to>');
      if (!store.profiles[from]) throw new Error(`Unknown profile: ${from}`);
      if (store.profiles[to] && !args.force) throw new Error(`Profile already exists: ${to}. Use --force.`);
      store.profiles[to] = store.profiles[from];
      store.profiles[to].name = to;
      store.profiles[to].updatedAt = new Date().toISOString();
      delete store.profiles[from];
      saveStore(store);
      ok(`renamed ${from} -> ${to}`);
      return;
    }
    if (command === 'export') {
      const file = args._[0];
      const payload = JSON.stringify(exportStore(store, Boolean(args['include-secrets'])), null, 2) + '\n';
      if (file) { writeFileAtomic(file, payload, args['include-secrets'] ? 0o600 : 0o644); ok(`exported profiles to ${file}`); }
      else process.stdout.write(payload);
      return;
    }
    if (command === 'import') { const file = args._[0]; if (!file) throw new Error('Missing import file'); importStore(file, args, store); return; }
    if (command === 'backups') {
      const backups = listBackups();
      if (!backups.length) { info('No backups yet.'); return; }
      backups.forEach((item) => console.log(`${item.id}\t${item.createdAt}\t${item.label}\t${item.files.length} file(s)`));
      return;
    }
    if (command === 'restore') { restoreBackup(args._[0] || 'latest', Boolean(args['dry-run'])); return; }
    if (command === 'shell-hook') { if (args.install) installShellHook(args); else console.log(shellHookLine()); return; }
    if (command === 'doctor') { commandDoctor(store, args); return; }
    throw new Error(`Unknown command: ${command}`);
  } catch (err) {
    console.error(`${color('red', '[ERROR]')} ${err.message}`);
    process.exit(1);
  }
}

main();
