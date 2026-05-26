#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const TEMPLATE_DIR = path.join(__dirname, '..', 'template');
const AVAILABLE_PACKS = ['web', 'data-science', 'none'];
const DEFAULT_PACK = 'web';
const LEGACY_WEB_FILES = [
  'docs/frontend-standards.md',
  'docs/backend-standards.md',
  'docs/api-spec.yml',
  'docs/data-model.md',
];

const stats = { copied: [], skipped: [], linked: [], moved: [], errors: [] };

function parseArgs(argv) {
  const args = { target: null, pack: null, migrate: false, help: false };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') args.help = true;
    else if (a === '--migrate') args.migrate = true;
    else if (a === '--pack') args.pack = argv[++i];
    else if (a.startsWith('--pack=')) args.pack = a.slice(7);
    else if (!args.target) args.target = a;
  }
  return args;
}

function ensureDir(dir) { fs.mkdirSync(dir, { recursive: true }); }
function pathExists(p) { try { fs.lstatSync(p); return true; } catch { return false; } }

function copyRecursive(src, dest, target) {
  ensureDir(dest);
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (entry.name === '.DS_Store') continue;
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyRecursive(srcPath, destPath, target);
    } else if (pathExists(destPath)) {
      stats.skipped.push(path.relative(target, destPath));
    } else {
      fs.copyFileSync(srcPath, destPath);
      stats.copied.push(path.relative(target, destPath));
    }
  }
}

function createSymlink(target, linkRelPath, symlinkTarget) {
  const full = path.join(target, linkRelPath);
  ensureDir(path.dirname(full));
  if (pathExists(full)) {
    stats.skipped.push(`${linkRelPath} (already exists)`);
    return;
  }
  try {
    fs.symlinkSync(symlinkTarget, full);
    stats.linked.push(`${linkRelPath} -> ${symlinkTarget}`);
  } catch (err) {
    stats.errors.push(`${linkRelPath}: ${err.message}`);
  }
}

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => rl.question(question, ans => { rl.close(); resolve(ans.trim()); }));
}

async function resolvePack(requested) {
  if (requested && AVAILABLE_PACKS.includes(requested)) return requested;
  if (requested) {
    console.error(`  ! Unknown pack "${requested}". Available: ${AVAILABLE_PACKS.join(', ')}`);
    process.exit(2);
  }
  if (!process.stdin.isTTY) return DEFAULT_PACK;
  console.log('  Available packs:');
  AVAILABLE_PACKS.forEach((p, i) => console.log(`    ${i + 1}) ${p}${p === DEFAULT_PACK ? '  (default)' : ''}`));
  const ans = await ask(`  Choose pack [${DEFAULT_PACK}]: `);
  if (!ans) return DEFAULT_PACK;
  if (/^\d+$/.test(ans)) return AVAILABLE_PACKS[Number(ans) - 1] || DEFAULT_PACK;
  return AVAILABLE_PACKS.includes(ans) ? ans : DEFAULT_PACK;
}

function copyBase(target) {
  // docs (excluding packs/)
  const tDocs = path.join(TEMPLATE_DIR, 'docs');
  for (const entry of fs.readdirSync(tDocs, { withFileTypes: true })) {
    if (entry.name === 'packs') continue;
    const src = path.join(tDocs, entry.name);
    const dest = path.join(target, 'docs', entry.name);
    if (entry.isDirectory()) copyRecursive(src, dest, target);
    else if (pathExists(dest)) stats.skipped.push(path.relative(target, dest));
    else { ensureDir(path.dirname(dest)); fs.copyFileSync(src, dest); stats.copied.push(path.relative(target, dest)); }
  }
  // ai-specs (excluding packs/)
  const tAi = path.join(TEMPLATE_DIR, 'ai-specs');
  for (const entry of fs.readdirSync(tAi, { withFileTypes: true })) {
    if (entry.name === 'packs') continue;
    const src = path.join(tAi, entry.name);
    const dest = path.join(target, 'ai-specs', entry.name);
    if (entry.isDirectory()) copyRecursive(src, dest, target);
    else if (pathExists(dest)) stats.skipped.push(path.relative(target, dest));
    else { ensureDir(path.dirname(dest)); fs.copyFileSync(src, dest); stats.copied.push(path.relative(target, dest)); }
  }
}

function copyPack(target, pack) {
  if (pack === 'none') return;
  const packDocs = path.join(TEMPLATE_DIR, 'docs', 'packs', pack);
  const packAgents = path.join(TEMPLATE_DIR, 'ai-specs', 'packs', pack, 'agents');
  if (!pathExists(packDocs)) {
    stats.errors.push(`pack "${pack}" not found in template`);
    return;
  }
  // Flatten pack docs into target/docs/
  for (const entry of fs.readdirSync(packDocs, { withFileTypes: true })) {
    if (entry.isDirectory()) continue;
    const src = path.join(packDocs, entry.name);
    const dest = path.join(target, 'docs', entry.name);
    if (pathExists(dest)) stats.skipped.push(path.relative(target, dest));
    else { fs.copyFileSync(src, dest); stats.copied.push(path.relative(target, dest)); }
  }
  // Flatten pack agents into target/ai-specs/agents/
  if (pathExists(packAgents)) {
    ensureDir(path.join(target, 'ai-specs', 'agents'));
    for (const entry of fs.readdirSync(packAgents, { withFileTypes: true })) {
      const src = path.join(packAgents, entry.name);
      const dest = path.join(target, 'ai-specs', 'agents', entry.name);
      if (pathExists(dest)) stats.skipped.push(path.relative(target, dest));
      else { fs.copyFileSync(src, dest); stats.copied.push(path.relative(target, dest)); }
    }
  }
}

function runMigrationIfNeeded(target, migrate) {
  // Detect legacy layout: docs/frontend-standards.md present AND no docs/packs/web marker.
  const hasLegacy = LEGACY_WEB_FILES.some(f => pathExists(path.join(target, f)));
  if (!hasLegacy) return;
  if (!migrate) {
    console.log('\n  ! Legacy web-only layout detected (docs/frontend-standards.md, etc.).');
    console.log('  ! Re-run with --migrate to relocate legacy files into docs/legacy/.');
    return;
  }
  const legacyDir = path.join(target, 'docs', 'legacy');
  ensureDir(legacyDir);
  for (const rel of LEGACY_WEB_FILES) {
    const src = path.join(target, rel);
    if (!pathExists(src)) continue;
    const dest = path.join(legacyDir, path.basename(rel));
    if (pathExists(dest)) { stats.skipped.push(path.relative(target, dest)); continue; }
    fs.renameSync(src, dest);
    stats.moved.push(`${rel} -> docs/legacy/${path.basename(rel)}`);
  }
}

function setupSymlinks(target) {
  for (const name of ['CLAUDE.md', 'AGENTS.md', 'codex.md', 'GEMINI.md']) {
    createSymlink(target, name, 'docs/base-standards.md');
  }
  const agentsDir = path.join(target, 'ai-specs', 'agents');
  const skillsDir = path.join(target, 'ai-specs', 'skills');
  const agents = pathExists(agentsDir) ? fs.readdirSync(agentsDir).filter(f => !f.startsWith('.')) : [];
  const skills = pathExists(skillsDir) ? fs.readdirSync(skillsDir).filter(f => !f.startsWith('.')) : [];
  for (const tool of ['.claude', '.cursor']) {
    for (const agent of agents) createSymlink(target, `${tool}/agents/${agent}`, `../../ai-specs/agents/${agent}`);
    for (const skill of skills) createSymlink(target, `${tool}/skills/${skill}`, `../../ai-specs/skills/${skill}`);
  }
}

function printHelp() {
  console.log(`
  lidr-specboot — Augmented Spec-Driven Development powered by OpenSpec

  Usage:
    npx @lidr/lidr-specboot [target-dir] [--pack <name>] [--migrate]

  Options:
    --pack <name>   Domain pack to install (${AVAILABLE_PACKS.join(' | ')}). Default: ${DEFAULT_PACK}.
    --migrate       Relocate legacy web-only layout into docs/legacy/ before applying packs.
    -h, --help      Show this help.
`);
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help) { printHelp(); return; }

  const target = args.target ? path.resolve(args.target) : process.cwd();
  ensureDir(target);

  console.log('\n  lidr-specboot');
  console.log('  Augmented Spec-driven development powered by OpenSpec\n');
  console.log(`  Target: ${target}`);

  runMigrationIfNeeded(target, args.migrate);

  const pack = await resolvePack(args.pack);
  console.log(`  Pack:   ${pack}\n`);

  copyBase(target);
  copyPack(target, pack);
  setupSymlinks(target);

  console.log(`  Files copied  ${stats.copied.length}`);
  console.log(`  Symlinks      ${stats.linked.length}`);
  console.log(`  Skipped       ${stats.skipped.length}`);
  if (stats.moved.length) console.log(`  Moved (legacy) ${stats.moved.length}`);

  if (stats.errors.length) {
    console.log(`\n  Errors (${stats.errors.length}):`);
    for (const e of stats.errors) console.log(`    ! ${e}`);
  }

  console.log('\n  Next steps:');
  console.log(`  1. Review docs/ — base-standards.md plus your pack's standards`);
  console.log('  2. openspec init');
  console.log('  3. /enrich-us  ->  /ff  ->  /apply\n');
}

main();
