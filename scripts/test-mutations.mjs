import { resolveToolchain } from "./environment.mjs";
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const output = path.resolve(process.argv[2] || path.join(root, 'work', `mutation-tests-${crypto.randomUUID()}`));
if (!/^D:\\/i.test(output) || fs.existsSync(output)) throw new Error('Choose a new D: mutation evidence directory.');
fs.mkdirSync(output, { recursive: true });
const pin = JSON.parse(fs.readFileSync(path.join(root,'toolchain.lock.json'),'utf8').replace(/^\uFEFF/,''));
const toolchain = resolveToolchain(root, pin);
const rows = [];
for (const [name, before, after] of [
  ['reverse-direction','direction == "provider-upgrade"','direction != "provider-upgrade"'],
  ['ignore-scalar-change','actual.shape != expected.shape','false'],
  ['swallow-unknown','f.status == "UNKNOWN"','f.status == "__MUTATED_UNKNOWN__"'],
]) {
  const project = path.join(output, name);
  fs.mkdirSync(project);
  fs.copyFileSync(path.join(root,'moon.mod'),path.join(project,'moon.mod'));
  fs.cpSync(path.join(root,'src'),path.join(project,'src'),{recursive:true});
  fs.cpSync(path.join(root,'.mooncakes'),path.join(project,'.mooncakes'),{recursive:true});
  fs.writeFileSync(path.join(project,'moon.work'),`members = [".", ${JSON.stringify(path.join(root,'work/vendor/wit').replaceAll('\\','/'))}]\n`);
  const file = path.join(project,'src/contract/compare.mbt'), source = fs.readFileSync(file,'utf8');
  if (source.split(before).length !== 2) throw new Error(`Mutation anchor is not unique: ${name}`);
  fs.writeFileSync(file,source.replace(before,after));
  const tmp = path.join(project,'tmp'); fs.mkdirSync(tmp);
  const result = spawnSync(path.join(toolchain,'bin/moon.exe'),['test','--target','js','-p','local/witprobe/analyzer'],{
    cwd:project,env:{...process.env,MOON_HOME:toolchain,TEMP:tmp,TMP:tmp,TMPDIR:tmp,
      MOON_DEP_CACHE:path.join(root,'work/cache/deps'),MOON_BUILD_CACHE:path.join(project,'cache/build')},
    encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:8*1024*1024,
  });
  fs.writeFileSync(path.join(project,'stdout.txt'),result.stdout || '');
  fs.writeFileSync(path.join(project,'stderr.txt'),result.stderr || '');
  const counts = /Total tests:\s*(\d+), passed:\s*(\d+), failed:\s*(\d+)/.exec((result.stdout || '') + (result.stderr || ''));
  const killed = !result.error && result.status !== 0 && counts && Number(counts[3]) > 0;
  rows.push({name,status:killed?'KILLED':'FAIL',exit_code:result.status,total_tests:counts?Number(counts[1]):null,
    failed_tests:counts?Number(counts[3]):null,error:result.error?.message || null,project});
}
const summary = {status:rows.every(r=>r.status==='KILLED')?'PASS':'FAIL',mutants:rows};
fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(summary,null,2)+'\n');
console.log(`Mutation validation: ${rows.filter(r=>r.status==='KILLED').length}/${rows.length} killed; ${output}`);
if(summary.status!=='PASS') console.error(JSON.stringify(summary,null,2));
process.exitCode=summary.status==='PASS'?0:1;
