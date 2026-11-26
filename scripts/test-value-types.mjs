import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {compare} from '../witprobe.mjs';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const output=path.resolve(process.argv[2]??path.join(root,'work',`value-tests-${Date.now()}`));
assert.match(output,/^D:\\/i);assert(!fs.existsSync(output),'Choose a fresh evidence directory');
fs.mkdirSync(output,{recursive:true});
const tool=path.join(root,'work/tools/wasm-tools-1.263.0-x86_64-windows/wasm-tools.exe');
const env={...process.env,TEMP:path.join(root,'work/tmp'),TMP:path.join(root,'work/tmp'),TMPDIR:path.join(root,'work/tmp')};
const rows=[];
const cases=[
  ['list','type t = list<u32>;','type t = list<u64>;'],
  ['option','type t = option<u32>;','type t = option<string>;'],
  ['tuple-order','type t = tuple<u32, string>;','type t = tuple<string, u32>;'],
  ['tuple-arity','type t = tuple<u32>;','type t = tuple<u32, u32>;'],
  ['result-ok','type t = result<u32, string>;','type t = result<u64, string>;'],
  ['result-err','type t = result<u32, string>;','type t = result<u32, u64>;'],
  ['result-empty','type t = result;','type t = result<u32>;'],
  ['result-branches','type t = result<_, string>;','type t = result<string>;'],
  ['record-order','record t { a: u32, b: string }','record t { b: string, a: u32 }'],
  ['record-field','record t { a: u32 }','record t { renamed: u32 }'],
  ['record-add','record t { a: u32 }','record t { a: u32, b: u32 }'],
  ['variant-payload','variant t { a, b(u32) }','variant t { a, b(u64) }'],
  ['variant-order','variant t { a, b }','variant t { b, a }'],
  ['variant-add','variant t { a, b }','variant t { a, b, c }'],
  ['enum-order','enum t { a, b }','enum t { b, a }'],
  ['enum-add','enum t { a, b }','enum t { a, b, c }'],
  ['flags-order','flags t { a, b }','flags t { b, a }'],
  ['flags-add','flags t { a, b }','flags t { a, b, c }'],
  ['nested','record item { x: u32 } type t = list<option<result<tuple<item, string>, string>>>;',
    'record item { x: u64 } type t = list<option<result<tuple<item, string>, string>>>;'],
];
function test(name,fn){try{fn();rows.push({name,status:'PASS'});}catch(e){rows.push({name,status:'FAIL',error:e.stack});}}
function source(def,version){return `package demo:values@${version}; interface api { ${def} f: func(x: t) -> t; } world app { export api; }\n`;}
for(const [name,oldDef,newDef] of cases){
  const dir=path.join(output,name);fs.mkdirSync(dir);
  const old=path.join(dir,'old'),next=path.join(dir,'new');
  for(const [p,def,v]of[[old,oldDef,'1.0.0'],[next,newDef,'2.0.0']]){
    fs.mkdirSync(p);fs.writeFileSync(path.join(p,'world.wit'),source(def,v));
  }
  const oracle=path.join(dir,'oracle');fs.mkdirSync(path.join(oracle,'deps'),{recursive:true});
  fs.cpSync(old,path.join(oracle,'deps/old'),{recursive:true});fs.cpSync(next,path.join(oracle,'deps/new'),{recursive:true});
  fs.writeFileSync(path.join(oracle,'world.wit'),'package validation:root; world root {}\n');
  for(const direction of ['provider-upgrade','consumer-upgrade'])test(`${name} ${direction}`,()=>{
    const report=compare(old,next,'app','app',direction);
    const actual=direction==='provider-upgrade'?'2.0.0':'1.0.0';
    const expected=direction==='provider-upgrade'?'1.0.0':'2.0.0';
    const args=['component','semver-check',oracle,'--prev',`demo:values/app@${actual}`,'--new',`demo:values/app@${expected}`];
    const ref=spawnSync(tool,args,{env,encoding:'utf8',timeout:30000,windowsHide:true});
    fs.writeFileSync(path.join(dir,direction+'.json'),JSON.stringify(report,null,2)+'\n');
    fs.writeFileSync(path.join(dir,direction+'.reference.json'),JSON.stringify({command:tool,args,exit:ref.status,stdout:ref.stdout,stderr:ref.stderr,error:ref.error?.message??null},null,2)+'\n');
    assert(!ref.error);assert.equal(ref.status,1);assert.match(ref.stderr,/not semver-compatible/);
    assert.equal(report.status,'BREAKING');assert.equal(report.exit_code,ref.status);
  });
  test(`${name} unchanged shape`,()=>assert.equal(compare(old,old,'app','app').status,'COMPATIBLE'));
}
function cli(args){const r=spawnSync(process.execPath,[path.join(root,'witprobe.mjs'),...args],{env,cwd:root,encoding:'utf8',timeout:120000,maxBuffer:32*1024*1024,windowsHide:true});assert(!r.error);return{...r,report:JSON.parse(r.stdout)};}
const large=path.join(output,'large');fs.mkdirSync(large);
const funcs=Array.from({length:40},(_,i)=>`call${i}: func(x: own<handle>);`).join('\n');
fs.writeFileSync(path.join(large,'world.wit'),`package demo:summary; interface api { resource handle; ${funcs} } world app { export api; }\n`);
test('CLI summary keeps exact counts and bounded details',()=>{
  const args=['compare','--old',large,'--new',large,'--world','app'];
  const compact=cli(args),full=cli([...args,'--detail','full']);
  fs.writeFileSync(path.join(output,'summary-view.json'),compact.stdout);
  fs.writeFileSync(path.join(output,'full-view.json'),full.stdout);
  assert.equal(compact.status,3);assert.equal(full.status,3);
  assert.equal(compact.report.schema_version,2);assert.equal(full.report.schema_version,2);
  assert.equal(compact.report.summary.finding_count,full.report.findings.length);
  assert.equal(compact.report.summary.groups.reduce((n,g)=>n+g.count,0),full.report.findings.length);
  assert.equal(compact.report.findings.length,20);assert.equal(compact.report.findings_truncated,true);
  assert(!('old_contract'in compact.report));assert('old_contract'in full.report);
  assert(compact.stdout.length<full.stdout.length/2);
});
// Markdown is text, so check it outside the JSON-only CLI helper.
test('summary and full Markdown expose accurate truncation and complete details',()=>{
  const args=[path.join(root,'witprobe.mjs'),'compare','--old',large,'--new',large,'--world','app','--format','markdown'];
  const compact=spawnSync(process.execPath,args,{env,encoding:'utf8',windowsHide:true,timeout:120000});
  const full=spawnSync(process.execPath,[...args,'--detail','full'],{env,encoding:'utf8',windowsHide:true,timeout:120000});
  fs.writeFileSync(path.join(output,'summary-view.md'),compact.stdout);fs.writeFileSync(path.join(output,'full-view.md'),full.stdout);
  assert.equal(compact.status,3);assert.equal(full.status,3);assert.match(compact.stdout,/Showing 20 of/);
  assert(!full.stdout.includes('Showing 20 of'));assert(full.stdout.length>compact.stdout.length);assert(full.stdout.includes('call39'));
});
test('legacy scalar baseline requires explicit migration',()=>{
  const baseline=path.join(output,'old-rules-baseline');
  const fixture=path.join(root,'fixtures/vertical/base');
  assert.equal(cli(['baseline','create','--wit',fixture,'--world','calculator-world','--out',baseline]).status,0);
  const meta=path.join(baseline,'baseline.json'),value=JSON.parse(fs.readFileSync(meta,'utf8'));value.rule_set_version='scalar-sync-v1';fs.writeFileSync(meta,JSON.stringify(value));
  const r=cli(['regression','run','--baseline',baseline,'--new',fixture]);
  assert.equal(r.status,2);assert.equal(r.report.error.code,'BASELINE_RULE_VERSION_CHANGED');
});
const summary={status:rows.every(r=>r.status==='PASS')?'PASS':'FAIL',total:rows.length,passed:rows.filter(r=>r.status==='PASS').length,official_differential:cases.length*2,tests:rows};
fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(summary,null,2)+'\n');
console.log(`Value-type/report checks: ${summary.passed}/${summary.total}; official differential ${summary.official_differential}; ${output}`);
for(const r of rows.filter(r=>r.status==='FAIL'))console.error(r.name+'\n'+r.error);
process.exitCode=summary.status==='PASS'?0:1;
