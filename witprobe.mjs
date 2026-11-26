import { resolveToolchain } from "./scripts/environment.mjs";
// Host I/O, hashes and process management only. Compatibility decisions live in MoonBit.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const pin = JSON.parse(fs.readFileSync(path.join(root, 'toolchain.lock.json'), 'utf8').replace(/^\uFEFF/, ''));
const toolchain = resolveToolchain(root, pin);
const backend = path.join(root, '_build/js/release/build/local/witprobe/cli/cli.js');
let ready = false;
const help = `WITProbe synchronous value-type prototype (MoonBit analysis, Node.js host)
  node witprobe.mjs compare --old PATH --new PATH --world NAME
       [--direction provider-upgrade|consumer-upgrade] [--format json|markdown] [--detail summary|full] [--out NEW_D_PATH]
  node witprobe.mjs baseline create --wit PATH --world NAME --out NEW_D_DIRECTORY
  node witprobe.mjs regression run --baseline PATH --new PATH [--new-world NAME]
       [--direction provider-upgrade|consumer-upgrade] [--format json|markdown] [--detail summary|full] [--out NEW_D_PATH]
Use --old-world/--new-world instead of --world when names differ.
Both comparisons use provider-world contracts; consumer-upgrade is the new caller's expectation.
Exit: 0 compatible/operation completed, 1 breaking, 2 input/tool/configuration error, 3 unknown.
No baseline is modified by regression. Output paths must be on D: in this workspace.
Default summary: counts by rule, at most 20 findings/changes, no embedded IR.
Use --detail full for all findings, change definitions and contract IR.
`;

function fail(code, message) { throw Object.assign(new Error(message), { code }); }
function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); }
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, canonical(value[k])]));
  return value;
}
function hash(value) { return crypto.createHash('sha256').update(typeof value === 'string' || Buffer.isBuffer(value) ? value : JSON.stringify(canonical(value))).digest('hex'); }
function dPath(target) {
  const resolved = path.resolve(target);
  if (!/^D:\\/i.test(resolved)) fail('OUTPUT_LOCATION', 'New output must be on D: for this workspace.');
  // Reject existing reparse/symlink ancestors rather than silently writing through them.
  let cursor = resolved;
  while (path.dirname(cursor) !== cursor) {
    if (fs.existsSync(cursor) && fs.lstatSync(cursor).isSymbolicLink()) fail('OUTPUT_SYMLINK', 'Output ancestors must not be symbolic links.');
    cursor = path.dirname(cursor);
  }
  return resolved;
}
function childEnv() {
  if (!/^D:\\/i.test(root) || !/^D:\\/i.test(toolchain)) fail('WORKSPACE_LOCATION', 'Project and configurable MoonBit home must remain on D: in this workspace.');
  const tmp = path.join(root, 'work/tmp');
  fs.mkdirSync(tmp, { recursive: true });
  return { ...process.env, MOON_HOME: toolchain, TEMP: tmp, TMP: tmp, TMPDIR: tmp,
    MOON_DEP_CACHE: path.join(root, 'work/cache/deps'), MOON_BUILD_CACHE: path.join(root, 'work/cache/build') };
}
function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: root, env: childEnv(), encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, timeout: 120000, windowsHide: true, ...options });
  if (result.error || result.status !== 0) fail('TOOL_ERROR', `${path.basename(command)} failed: ${result.error?.message ?? result.stderr ?? result.status}`);
  return result.stdout;
}
function ensureBuild() {
  if (ready) return;
  if (!toolchain) fail("TOOLCHAIN_MISSING", "Run scripts/prepare.ps1 -Toolchain <existing D: MoonBit installation> first.");
  const moon = path.join(toolchain, 'bin/moon.exe');
  const versions = run(moon, ['version', '--all']).split(/\r?\n/);
  if (!versions[0]?.startsWith(`moon ${pin.moon} `) || !versions[1]?.startsWith(`moonc ${pin.moonc} `)) fail('TOOLCHAIN_VERSION', 'MoonBit differs from toolchain.lock.json.');
  const vendor = path.join(root, 'work/vendor/wit');
  if (run('git', ['-C', vendor, 'rev-parse', 'HEAD']).trim() !== pin.wit.commit || (run('git', ['-C', vendor, 'diff', '--exit-code', '--no-ext-diff', '--no-textconv', 'HEAD', '--']).trim() || run('git', ['-C', vendor, 'ls-files', '--others', '--exclude-standard']).trim())) fail('PARSER_PIN', 'Parser checkout differs from its fixed revision.');
  run(moon, ['build', 'src/cli', '--target', 'js', '--release']);
  ready = true;
}

export function compare(oldPath, newPath, oldWorld, newWorld, direction = 'provider-upgrade') {
  if (!['provider-upgrade', 'consumer-upgrade'].includes(direction)) fail('INVALID_DIRECTION', 'Choose provider-upgrade or consumer-upgrade.');
  if (!oldWorld || !newWorld) fail('WORLD_REQUIRED', 'Specify --world or both --old-world and --new-world.');
  ensureBuild();
  const report = JSON.parse(run(process.execPath, [backend, path.resolve(oldPath), path.resolve(newPath), oldWorld, newWorld, direction]));
  const expectedCodes = { COMPATIBLE: 0, BREAKING: 1, ERROR: 2, UNKNOWN: 3 };
  if (expectedCodes[report.status] !== report.exit_code) fail('INVALID_BACKEND_REPORT', 'Backend status and exit code disagree.');
  report.parser = { module: pin.wit.module, version: pin.wit.version, commit: pin.wit.commit };
  report.parse_options = { features: [], all_features: false, target_version: null };
  if (report.status !== 'ERROR') {
    report.identity_mapping = { root_package: report.old_contract.root_identity,
      old_version: report.old_contract.source_version ?? null, new_version: report.new_contract.source_version ?? null };
    report.old_semantic_hash = hash(report.old_semantic_contract);
    report.new_semantic_hash = hash(report.new_semantic_contract);
  }
  return report;
}

function sources(input) {
  const selected = path.resolve(input);
  if (fs.lstatSync(selected).isSymbolicLink()) fail('SOURCE_SYMLINK', 'Baseline sources must not be symbolic links.');
  const directory = fs.statSync(selected).isDirectory();
  const sourceRoot = directory ? selected : path.dirname(selected);
  const files = [];
  let totalBytes = 0;
  function add(file, relative) {
    const stat = fs.lstatSync(file);
    if (stat.isSymbolicLink() || !stat.isFile()) fail('SOURCE_SYMLINK', 'Baseline sources must be regular files.');
    const bytes = fs.readFileSync(file);
    totalBytes += bytes.length;
    if (files.length >= 10000 || totalBytes > 64 * 1024 * 1024) fail('SOURCE_LIMIT', 'Baseline exceeds 10,000 WIT files or 64 MiB.');
    files.push({ path: relative.replaceAll('\\', '/'), sha256: hash(bytes), size: bytes.length, absolute: file });
  }
  function walkDeps(dir, relative) {
    if (!fs.existsSync(dir)) return;
    if (fs.lstatSync(dir).isSymbolicLink()) fail('SOURCE_SYMLINK', 'Dependency directories must not be symbolic links.');
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name, 'en'))) {
      const file = path.join(dir, entry.name), rel = path.join(relative, entry.name);
      if (entry.isSymbolicLink()) fail('SOURCE_SYMLINK', 'Dependency trees must not contain symbolic links.');
      if (entry.isDirectory()) walkDeps(file, rel);
      else if (entry.name.endsWith('.wit')) add(file, rel);
    }
  }
  if (directory) {
    for (const name of fs.readdirSync(selected).sort()) if (name.endsWith('.wit')) add(path.join(selected, name), name);
  } else {
    if (!selected.endsWith('.wit')) fail('WIT_INPUT_REQUIRED', 'A source baseline requires a WIT file or WIT directory.');
    add(selected, path.basename(selected));
  }
  walkDeps(path.join(sourceRoot, 'deps'), 'deps');
  files.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
  const manifest = files.map(({ path, sha256, size }) => ({ path, sha256, size }));
  return { files, manifest, source_hash: hash(manifest), entry: directory ? '.' : path.basename(selected) };
}

export function createBaseline(input, world, output) {
  const destination = dPath(output);
  if (fs.existsSync(destination)) fail('BASELINE_EXISTS', 'Baseline creation refuses to overwrite an existing path.');
  const selected = path.resolve(input);
  const inputRoot = fs.statSync(selected).isDirectory() ? selected : path.dirname(selected);
  if (destination.toLowerCase().startsWith(inputRoot.toLowerCase() + path.sep)) fail('BASELINE_INSIDE_SOURCE', 'Place the baseline outside the input source tree.');
  if (!world) fail('WORLD_REQUIRED', 'Baseline requires --world.');
  const original = sources(input);
  // Validate before creating the destination, then analyze the copied snapshot again.
  const initial = compare(input, input, world, world);
  if (initial.status === 'ERROR') return initial;
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.mkdirSync(destination);
  const sourceDir = path.join(destination, 'source');
  fs.mkdirSync(sourceDir);
  for (const file of original.files) {
    const target = path.join(sourceDir, file.path);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(file.absolute, target, fs.constants.COPYFILE_EXCL);
  }
  const snapshotPath = path.join(sourceDir, original.entry);
  const copied = sources(snapshotPath);
  if (original.source_hash !== copied.source_hash) fail('SOURCE_CHANGED', 'Source changed while snapshotting; partial output is retained for inspection.');
  const report = compare(snapshotPath, snapshotPath, world, world);
  if (report.status === 'ERROR') fail('SNAPSHOT_PARSE_ERROR', 'Copied snapshot failed validation; partial output is retained.');
  const meta = { schema_version: 1, ir_schema_version: report.old_contract.schema_version, rule_set_version: report.rule_set_version,
    analysis_scope: report.analysis_scope, parser: report.parser, parse_options: report.parse_options,
    entry: original.entry, world, source_manifest: copied.manifest, source_hash: copied.source_hash,
    semantic_hash: report.old_semantic_hash, contract_hash: hash(report.old_contract), analysis_status: report.status };
  fs.writeFileSync(path.join(destination, 'contract.json'), JSON.stringify(report.old_contract, null, 2) + '\n', { flag: 'wx' });
  fs.writeFileSync(path.join(destination, 'baseline.json'), JSON.stringify(meta, null, 2) + '\n', { flag: 'wx' });
  return { schema_version: 2, status: 'BASELINE_CREATED', exit_code: 0, baseline: destination, baseline_analysis_status: report.status,
    source_hash: meta.source_hash, semantic_hash: meta.semantic_hash, rule_set_version: meta.rule_set_version };
}

export function regression(baseline, input, newWorld, direction = 'provider-upgrade') {
  const directory = path.resolve(baseline), meta = readJson(path.join(directory, 'baseline.json'));
  if (meta.schema_version !== 1 || meta.ir_schema_version !== 1 || meta.analysis_scope !== 'structural') fail('BASELINE_SCHEMA', 'Baseline schema/scope is unsupported.');
  if (JSON.stringify(canonical(meta.parser)) !== JSON.stringify(canonical({ module: pin.wit.module, version: pin.wit.version, commit: pin.wit.commit }))) fail('BASELINE_PARSER_CHANGED', 'Parser changed; baseline migration requires explicit review.');
  if (JSON.stringify(canonical(meta.parse_options)) !== JSON.stringify(canonical({ features: [], all_features: false, target_version: null }))) fail('BASELINE_OPTIONS_CHANGED', 'Baseline parse options differ.');
  if (typeof meta.entry !== 'string' || (meta.entry !== '.' && (meta.entry !== path.basename(meta.entry) || !meta.entry.endsWith('.wit')))) fail('BASELINE_ENTRY', 'Invalid baseline source entry.');
  const snapshot = path.join(directory, 'source', meta.entry), current = sources(snapshot);
  if (current.source_hash !== meta.source_hash || hash(current.manifest) !== hash(meta.source_manifest)) fail('BASELINE_SOURCE_MODIFIED', 'Baseline source bytes or filenames changed.');
  if (hash(readJson(path.join(directory, 'contract.json'))) !== meta.contract_hash) fail('BASELINE_IR_MODIFIED', 'Baseline IR changed.');
  const report = compare(snapshot, input, meta.world, newWorld || meta.world, direction);
  if (report.status === 'ERROR') return report;
  if (report.rule_set_version !== meta.rule_set_version) fail('BASELINE_RULE_VERSION_CHANGED', 'Rules changed; recomputing the baseline requires explicit review.');
  if (report.old_semantic_hash !== meta.semantic_hash) fail('BASELINE_SEMANTICS_CHANGED', 'Reparsed baseline differs from its recorded semantic contract.');
  const newSources = sources(input);
  report.baseline_changes = { source_changed: newSources.source_hash !== meta.source_hash,
    contract_changed: report.new_semantic_hash !== meta.semantic_hash, rule_changed: false };
  report.baseline = { source_hash: meta.source_hash, semantic_hash: meta.semantic_hash, rule_set_version: meta.rule_set_version };
  return report;
}

function parseOptions(args, allowed) {
  const options = {};
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i]?.replace(/^--/, '');
    if (!args[i]?.startsWith('--') || !allowed.includes(key) || args[i + 1] === undefined || args[i + 1].startsWith('--') || Object.hasOwn(options, key)) fail('ARGUMENT_ERROR', `Unknown, duplicate or incomplete option: ${args[i]}`);
    options[key] = args[i + 1];
  }
  return options;
}
function required(options, key) { if (!options[key]) fail('ARGUMENT_ERROR', `Missing --${key}`); return options[key]; }
function emit(report, options) {
  if (options.format && !['json', 'markdown'].includes(options.format)) fail('FORMAT_ERROR', 'Choose json or markdown.');
  if (options.detail && !['summary', 'full'].includes(options.detail)) fail('DETAIL_ERROR', 'Choose summary or full.');
  const full = options.detail === 'full';
  let view = report;
  if (report.summary) {
    // Presentation only: the MoonBit report owns every decision and count.
    view = { ...report, detail: full ? 'full' : 'summary' };
    if (!full) {
      for (const key of ['old_contract','new_contract','old_semantic_contract','new_semantic_contract','summary_markdown']) delete view[key];
      view.findings = report.findings.slice(0, 20);
      view.changes = report.changes.slice(0, 20).map(({ kind, symbol }) => ({ kind, symbol }));
      view.findings_truncated = report.findings.length > view.findings.length;
      view.changes_truncated = report.changes.length > view.changes.length;
      view.markdown = report.summary_markdown;
      view.full_report_hint = 'Rerun with --detail full to retain all findings, definitions and IR.';
    } else delete view.summary_markdown;
  }
  const markdown = full ? report.markdown : (report.summary_markdown ?? report.markdown);
  const text = options.format === 'markdown' ? (markdown ?? `# WITProbe\n\nStatus: ${report.status}\n${report.error?.message ?? ''}\n`) : JSON.stringify(view, null, 2) + '\n';
  if (options.out) {
    const output = dPath(options.out);
    if (fs.existsSync(output)) fail('OUTPUT_EXISTS', 'Report output already exists; choose a new path.');
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.writeFileSync(output, text, { flag: 'wx' });
  } else process.stdout.write(text);
  process.exitCode = report.exit_code;
}

function main(argv) {
  if (!argv.length || argv[0] === '--help') { process.stdout.write(help); return; }
  let options, report;
  if (argv[0] === 'compare') {
    options = parseOptions(argv.slice(1), ['old','new','world','old-world','new-world','direction','format','detail','out']);
    report = compare(required(options, 'old'), required(options, 'new'), options['old-world'] || options.world, options['new-world'] || options.world, options.direction);
  } else if (argv[0] === 'baseline' && argv[1] === 'create') {
    options = parseOptions(argv.slice(2), ['wit','world','out']);
    report = createBaseline(required(options, 'wit'), required(options, 'world'), required(options, 'out'));
    options = {};
  } else if (argv[0] === 'regression' && argv[1] === 'run') {
    options = parseOptions(argv.slice(2), ['baseline','new','new-world','direction','format','detail','out']);
    report = regression(required(options, 'baseline'), required(options, 'new'), options['new-world'], options.direction);
  } else fail('ARGUMENT_ERROR', 'Unknown command; use --help.');
  emit(report, options);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); }
  catch (error) {
    process.stdout.write(JSON.stringify({ schema_version: 2, status: 'ERROR', exit_code: 2,
      error: { code: error.code || 'IO_OR_TOOL_ERROR', message: error.message } }, null, 2) + '\n');
    process.exitCode = 2;
  }
}
