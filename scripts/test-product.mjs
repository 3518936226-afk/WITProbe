import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { compare, createBaseline, regression } from '../witprobe.mjs';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const output = path.resolve(process.argv[2] || path.join(root, 'work', `product-tests-${crypto.randomUUID()}`));
assert.match(output, /^D:\\/i);
assert(!fs.existsSync(output), 'test output must be new');
fs.mkdirSync(output, { recursive: true });
const rows = [];
function test(name, fn) {
  try { fn(); rows.push({ name, status: 'PASS' }); }
  catch (error) { rows.push({ name, status: 'FAIL', error: error.stack }); }
}
const fixture = name => path.join(root, 'fixtures/vertical', name);
const world = 'calculator-world';
const baseline = path.join(output, 'baseline');
function cli(args) {
  const result = spawnSync(process.execPath, [path.join(root, 'witprobe.mjs'), ...args], { cwd: root, encoding: 'utf8', windowsHide: true, timeout: 120000 });
  if (result.error) throw result.error;
  return { exit: result.status, text: result.stdout, report: JSON.parse(result.stdout) };
}
function treeHashes(dir) {
  const rows = [];
  function walk(p) { for (const e of fs.readdirSync(p, { withFileTypes: true })) e.isDirectory() ? walk(path.join(p, e.name)) : rows.push([path.relative(dir, path.join(p, e.name)), crypto.createHash('sha256').update(fs.readFileSync(path.join(p, e.name))).digest('hex')]); }
  walk(dir); return rows.sort((a, b) => a[0].localeCompare(b[0]));
}

test('provider accepts added export and reports member path', () => {
  const r = compare(fixture('base'), fixture('added'), world, world);
  assert.equal(r.status, 'COMPATIBLE');
  assert(r.changes.some(c => c.kind === 'FUNCTION_ADDED' && c.symbol.endsWith('/function/subtract')));
});
test('consumer rejects added requirement and identifies actual/expected', () => {
  const r = compare(fixture('base'), fixture('added'), world, world, 'consumer-upgrade');
  assert.equal(r.status, 'BREAKING'); assert.equal(r.actual_side, 'old'); assert.equal(r.expected_side, 'new');
});
test('type change finds exact parameters and result', () => {
  const r = compare(fixture('base'), fixture('breaking'), world, world);
  assert.equal(r.exit_code, 1); assert.equal(r.findings.filter(f => f.rule_id === 'TYPE_CHANGED').length, 3);
});
test('public unused record containing a resource produces unknown reason and action', () => {
  const r = compare(fixture('base'), fixture('unknown'), world, world);
  assert.equal(r.status, 'UNKNOWN'); assert.equal(r.exit_code, 3);
  assert(r.findings.some(f => f.symbol.includes('/type/future-item') && f.rule_id === 'UNSUPPORTED_RESOURCE' && f.action));
});
for (const [name, newPath, code, status] of [
  ['compatible', fixture('base'), 0, 'COMPATIBLE'], ['breaking', fixture('breaking'), 1, 'BREAKING'],
  ['unknown', fixture('unknown'), 3, 'UNKNOWN'], ['invalid input', path.join(root, 'fixtures/invalid-duplicate'), 2, 'ERROR']
]) test(`real CLI exit ${code}: ${name}`, () => {
  const result = cli(['compare', '--old', fixture('base'), '--new', newPath, '--world', world]);
  assert.equal(result.exit, code); assert.equal(result.report.exit_code, code); assert.equal(result.report.status, status);
});
test('missing world is an input error', () => {
  const r = cli(['compare','--old',fixture('base'),'--new',fixture('base'),'--world','missing']);
  assert.equal(r.exit, 2); assert.equal(r.report.status, 'ERROR');
});
test('missing and duplicate options are rejected', () => {
  assert.equal(cli(['compare','--old',fixture('base')]).exit, 2);
  assert.equal(cli(['compare','--old',fixture('base'),'--old',fixture('base')]).exit, 2);
});
test('independent processes give identical semantic hashes', () => {
  const args = ['compare','--old',fixture('base'),'--new',fixture('added'),'--world',world];
  const a = cli(args), b = cli(args);
  assert.equal(a.report.new_semantic_hash, b.report.new_semantic_hash);
  assert.deepEqual(a.report.changes, b.report.changes);
});
test('JSON and Markdown are generated from the same findings', () => {
  const r = compare(fixture('base'), fixture('breaking'), world, world);
  assert(r.markdown.includes(`Status: ${r.status}`));
  for (const f of r.findings) assert(r.markdown.includes(f.rule_id) && r.markdown.includes(f.symbol));
});
test('baseline creation records source, semantic and rule identities', () => {
  const r = createBaseline(fixture('base'), world, baseline);
  assert.equal(r.status, 'BASELINE_CREATED');
  const meta = JSON.parse(fs.readFileSync(path.join(baseline,'baseline.json')));
  assert.match(meta.source_hash, /^[a-f0-9]{64}$/); assert.match(meta.semantic_hash, /^[a-f0-9]{64}$/);
  assert.equal(meta.rule_set_version, 'value-sync-v2'); assert.equal(meta.ir_schema_version, 1);
});
test('baseline overwrite is refused', () => assert.throws(() => createBaseline(fixture('base'), world, baseline), e => e.code === 'BASELINE_EXISTS'));
test('regression leaves every baseline file unchanged', () => {
  const before = treeHashes(baseline);
  assert.equal(regression(baseline, fixture('breaking')).status, 'BREAKING');
  assert.deepEqual(treeHashes(baseline), before);
});
test('comments distinguish source changes from contract changes', () => {
  const r = regression(baseline, fixture('comment-only'));
  assert.equal(r.status, 'COMPATIBLE');
  assert.deepEqual(r.baseline_changes, { source_changed: true, contract_changed: false, rule_changed: false });
});
test('signature changes distinguish semantic changes', () => {
  assert.equal(regression(baseline, fixture('breaking')).baseline_changes.contract_changed, true);
});
test('modified baseline sources are rejected', () => {
  const copy = path.join(output, 'tampered-source'); fs.cpSync(baseline, copy, { recursive: true });
  fs.appendFileSync(path.join(copy,'source/world.wit'), '\n// changed after baseline creation\n');
  assert.throws(() => regression(copy, fixture('base')), e => e.code === 'BASELINE_SOURCE_MODIFIED');
});
test('modified baseline IR is rejected', () => {
  const copy = path.join(output, 'tampered-ir'); fs.cpSync(baseline, copy, { recursive: true });
  fs.writeFileSync(path.join(copy,'contract.json'), '{}');
  assert.throws(() => regression(copy, fixture('base')), e => e.code === 'BASELINE_IR_MODIFIED');
});
test('changed rule version requires explicit migration', () => {
  const copy = path.join(output, 'rule-drift'); fs.cpSync(baseline, copy, { recursive: true });
  const file = path.join(copy,'baseline.json'), meta = JSON.parse(fs.readFileSync(file));
  meta.rule_set_version = 'future-rules'; fs.writeFileSync(file, JSON.stringify(meta));
  assert.throws(() => regression(copy, fixture('base')), e => e.code === 'BASELINE_RULE_VERSION_CHANGED');
});
test('changed parser pin requires explicit migration', () => {
  const copy = path.join(output, 'parser-drift'); fs.cpSync(baseline, copy, { recursive: true });
  const file = path.join(copy,'baseline.json'), meta = JSON.parse(fs.readFileSync(file));
  meta.parser.commit = 'different'; fs.writeFileSync(file, JSON.stringify(meta));
  assert.throws(() => regression(copy, fixture('base')), e => e.code === 'BASELINE_PARSER_CHANGED');
});
test('C-drive output is refused before any creation', () => {
  assert.throws(() => createBaseline(fixture('base'), world, 'C:\\WITProbe-not-created'), e => e.code === 'OUTPUT_LOCATION');
});
test('regression CLI blocks a breaking change with exit 1', () => {
  const r = cli(['regression','run','--baseline',baseline,'--new',fixture('breaking')]);
  assert.equal(r.exit, 1); assert.equal(r.report.status, 'BREAKING');
});
test('report output overwrite is refused', () => {
  const out = path.join(output,'already-exists.json'); fs.writeFileSync(out,'preserve');
  const r = cli(['compare','--old',fixture('base'),'--new',fixture('base'),'--world',world,'--out',out]);
  assert.equal(r.exit,2); assert.equal(fs.readFileSync(out,'utf8'),'preserve');
});

const wasmTools = path.join(root, 'work/tools/wasm-tools-1.263.0-x86_64-windows/wasm-tools.exe');
const oracleRows = [];
for (const [label, oldWorld, newWorld] of [['export-added','baseline','more-exports'],['import-added','baseline','more-imports'],['export-removed','more-exports','baseline'],['import-removed','more-imports','baseline']]) {
  for (const direction of ['provider-upgrade','consumer-upgrade']) test(`official differential ${label} ${direction}`, () => {
    const fixturePath = path.join(root,'fixtures/oracle-directions');
    const r = compare(fixturePath, fixturePath, oldWorld, newWorld, direction);
    const prev = direction === 'provider-upgrade' ? newWorld : oldWorld;
    const expected = direction === 'provider-upgrade' ? oldWorld : newWorld;
    const oracle = spawnSync(wasmTools,['component','semver-check',fixturePath,'--prev',prev,'--new',expected],{encoding:'utf8',windowsHide:true,timeout:30000});
    assert(!oracle.error); assert([0,1].includes(oracle.status));
    if (oracle.status === 1) assert.match(oracle.stderr, /not semver-compatible/);
    assert.equal(r.exit_code,oracle.status);
    oracleRows.push({label,direction,actual_side:r.actual_side,expected_side:r.expected_side,tool_prev:prev,tool_new:expected,product_exit:r.exit_code,oracle_exit:oracle.status,stderr:oracle.stderr});
  });
}
fs.writeFileSync(path.join(output,'oracle-differential.json'),JSON.stringify(oracleRows,null,2)+'\n');
const summary={status:rows.every(r=>r.status==='PASS')?'PASS':'FAIL',total:rows.length,passed:rows.filter(r=>r.status==='PASS').length,tests:rows};
fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(summary,null,2)+'\n');
console.log(`Product integration: ${summary.passed}/${summary.total}; ${output}`);
for(const row of rows.filter(r=>r.status==='FAIL')) console.error(row.name+'\n'+row.error);
process.exitCode=summary.status==='PASS'?0:1;
