import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {compare,createBaseline,regression} from '../witprobe.mjs';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const corpus=path.resolve(process.argv[2]??'');
const output=path.resolve(process.argv[3]??path.join(root,'work',`real-tests-${Date.now()}`));
assert(process.argv[2],'Supply the downloaded pinned corpus directory');assert.match(output,/^D:\\/i);assert(!fs.existsSync(output),'Choose a fresh evidence directory');
fs.mkdirSync(output,{recursive:true});
const read=(p)=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const digest=(p)=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const manifest=read(path.join(corpus,'../corpus-manifest.json'));
for(const entry of manifest)for(const file of entry.files)assert.equal(digest(path.join(corpus,entry.label,file.path)),file.sha256,`Upstream source changed: ${entry.label}/${file.path}`);
const source=(pkg,v)=>path.join(corpus,`wasi-${pkg}-v${v}/wit`);
const tool=path.join(root,'work/tools/wasm-tools-1.263.0-x86_64-windows/wasm-tools.exe');
const env={...process.env,TEMP:path.join(root,'work/tmp'),TMP:path.join(root,'work/tmp'),TMPDIR:path.join(root,'work/tmp')};
const rows=[],metrics=[];
function save(name,value){fs.writeFileSync(path.join(output,name+'.json'),JSON.stringify(value,null,2)+'\n');}
function test(name,fn){try{fn();rows.push({name,status:'PASS'});}catch(e){rows.push({name,status:'FAIL',error:e.stack});}}
function official(name,args,expected){
  const r=spawnSync(tool,args,{env,encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:32*1024*1024});
  save(name,{command:tool,args,exit:r.status,stdout:r.stdout,stderr:r.stderr,error:r.error?.message??null});
  assert(!r.error);assert.equal(r.status,expected);if(expected===1)assert.match(r.stderr,/not semver-compatible/);
}
function hashes(dir){return fs.readdirSync(dir,{recursive:true,withFileTypes:true}).filter(e=>e.isFile()).map(e=>{
  const f=path.join(e.parentPath,e.name);return[path.relative(dir,f),digest(f)];
}).sort((a,b)=>a[0].localeCompare(b[0]));}
for(const pkg of ['random','cli']){
  const world=pkg==='cli'?'command':'imports';
  const expectedStatus=pkg==='random'?'COMPATIBLE':'UNKNOWN';
  const expectedExit=pkg==='random'?0:3;
  for(const v of ['0.2.0','0.2.1']){
    test(`${pkg} ${v} official parse`,()=>official(`${pkg}-${v}-official-parse`,['component','wit',source(pkg,v),'--json'],0));
    test(`${pkg} ${v} unchanged real World`,()=>{
      const r=compare(source(pkg,v),source(pkg,v),world,world);save(`${pkg}-${v}-self`,r);
      assert.equal(r.status,'COMPATIBLE');assert.equal(r.exit_code,0);
    });
  }
  const oracle=path.join(output,'oracle',pkg);fs.mkdirSync(path.join(oracle,'deps'),{recursive:true});
  for(const v of ['0.2.0','0.2.1']){
    const dest=path.join(oracle,'deps',pkg+'-'+v);fs.mkdirSync(dest);
    for(const e of fs.readdirSync(source(pkg,v),{withFileTypes:true}))if(e.isFile()&&e.name.endsWith('.wit'))fs.copyFileSync(path.join(source(pkg,v),e.name),path.join(dest,e.name));
    if(fs.existsSync(path.join(source(pkg,v),'deps')))for(const e of fs.readdirSync(path.join(source(pkg,v),'deps'),{withFileTypes:true}))if(e.isDirectory())fs.cpSync(path.join(source(pkg,v),'deps',e.name),path.join(oracle,'deps',e.name+'-'+v),{recursive:true});
  }
  fs.writeFileSync(path.join(oracle,'world.wit'),`package validation:${pkg}; world root {}\n`);
  for(const direction of ['provider-upgrade','consumer-upgrade']){
    const actual=direction==='provider-upgrade'?'0.2.1':'0.2.0';
    const expected=direction==='provider-upgrade'?'0.2.0':'0.2.1';
    test(`${pkg} reference release pair ${direction}`,()=>official(`${pkg}-reference-${direction}`,['component','semver-check',oracle,'--prev',`wasi:${pkg}/${world}@${actual}`,'--new',`wasi:${pkg}/${world}@${expected}`],0));
    test(`${pkg} release pair ${direction}`,()=>{
      const r=compare(source(pkg,'0.2.0'),source(pkg,'0.2.1'),world,world,direction);save(`${pkg}-${direction}`,r);
      assert.equal(r.status,expectedStatus);assert.equal(r.exit_code,expectedExit);
      if(pkg==='random')assert.equal(r.findings.length,0);
      else {
        assert(!r.findings.some(f=>f.rule_id==='UNSUPPORTED_RESOURCE')); 
        assert(r.findings.some(f=>f.rule_id==='UNMAPPED_DEPENDENCY_VERSION'));
        assert(!r.findings.some(f=>f.rule_id==='UNSUPPORTED_COMPOSITE'));
      }
    });
  }
  const baseline=path.join(output,pkg+'-baseline');
  test(`${pkg} baseline/regression integrity`,()=>{
    const created=createBaseline(source(pkg,'0.2.0'),world,baseline);save(pkg+'-baseline-created',created);
    assert.equal(created.baseline_analysis_status,'COMPATIBLE');
    const before=hashes(baseline),r=regression(baseline,source(pkg,'0.2.1'));
    save(pkg+'-regression',r);assert.equal(r.status,expectedStatus);assert.deepEqual(hashes(baseline),before);
  });
  if(pkg==='cli') {
    const mapFile=path.join(root,'fixtures/wasi-cli-0.2.0-to-0.2.1.mapping.json');
    const mapping=read(mapFile);
    for(const direction of ['provider-upgrade','consumer-upgrade'])test('CLI explicitly mapped '+direction,()=>{
      const r=compare(source(pkg,'0.2.0'),source(pkg,'0.2.1'),world,world,direction,mapping);
      save('cli-mapped-'+direction,r);assert.equal(r.status,'COMPATIBLE');assert.equal(r.findings.length,0);
      assert.equal(r.dependency_mappings.length,5);assert.match(r.mapping_sha256,/^[a-f0-9]{64}$/);
      assert(r.markdown.includes('wasi:io@0.2.1'));
      assert(r.new_contract.imports.some(e=>e.key.includes('@0.2.1')));
      assert(r.comparison_new_contract.imports.some(e=>e.key.includes('@0.2.0')));
      const permuted={...mapping,packages:[...mapping.packages].reverse()};
      assert.equal(compare(source(pkg,'0.2.0'),source(pkg,'0.2.1'),world,world,direction,permuted).mapping_sha256,r.mapping_sha256);
    });
    test('CLI mapped regression and actual gate',()=>{
      const before=hashes(baseline);
      const r=regression(baseline,source(pkg,'0.2.1'),undefined,'provider-upgrade',mapping);save('cli-mapped-regression',r);
      assert.equal(r.status,'COMPATIBLE');assert.deepEqual(hashes(baseline),before);
      const args=['-NoProfile','-File',path.join(root,'scripts/ci-gate.ps1'),'-Baseline',baseline,'-New',source(pkg,'0.2.1'),'-DependencyMap',mapFile];
      const gate=spawnSync('pwsh',args,{env,encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:32*1024*1024});
      save('cli-mapped-gate',{command:'pwsh',args,exit:gate.status,stdout:gate.stdout,stderr:gate.stderr});
      assert(!gate.error);assert.equal(gate.status,0);
    });
    test('CLI partial mapping does not erase remaining versions',()=>{
      const r=compare(source(pkg,'0.2.0'),source(pkg,'0.2.1'),world,world,'provider-upgrade',{schema_version:1,packages:mapping.packages.slice(0,1)});
      save('cli-partial-map',r);assert.equal(r.status,'UNKNOWN');
    });
  }
  test(`${pkg} actual local gate exit`,()=>{
    const args=['-NoProfile','-File',path.join(root,'scripts/ci-gate.ps1'),'-Baseline',baseline,'-New',source(pkg,'0.2.1')];
    const r=spawnSync('pwsh',args,{env,encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:32*1024*1024});
    save(pkg+'-gate',{command:'pwsh',args,exit:r.status,stdout:r.stdout,stderr:r.stderr,error:r.error?.message??null});
    assert(!r.error);assert.equal(r.status,expectedExit);
  });
  test(`${pkg} real summary/full report parity`,()=>{
    const args=[path.join(root,'witprobe.mjs'),'compare','--old',source(pkg,'0.2.0'),'--new',source(pkg,'0.2.1'),'--world',world];
    const start=performance.now();
    const compact=spawnSync(process.execPath,args,{env,encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:32*1024*1024});
    const elapsed_ms=Math.round(performance.now()-start);
    const full=spawnSync(process.execPath,[...args,'--detail','full'],{env,encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:32*1024*1024});
    fs.writeFileSync(path.join(output,pkg+'-summary-cli.json'),compact.stdout??'');fs.writeFileSync(path.join(output,pkg+'-full-cli.json'),full.stdout??'');
    assert(!compact.error);assert(!full.error);assert.equal(compact.status,expectedExit);assert.equal(full.status,expectedExit);
    const a=JSON.parse(compact.stdout),b=JSON.parse(full.stdout);
    assert.deepEqual(a.summary,b.summary);assert.equal(a.summary.finding_count,b.findings.length);
    assert.equal(a.new_semantic_hash,b.new_semantic_hash);assert.equal(a.status,b.status);
    assert(a.findings.length<=20);assert(!('old_contract'in a));assert('old_contract'in b);
    if(pkg==='cli'){
      assert.equal(a.findings_truncated,true);assert.equal(a.changes_truncated,true);
      assert(Buffer.byteLength(compact.stdout)<Buffer.byteLength(full.stdout)/3);
    }
    metrics.push({project:pkg,status:a.status,exit:a.exit_code,findings:a.summary.finding_count,groups:a.summary.groups,
      summary_bytes:Buffer.byteLength(compact.stdout),full_bytes:Buffer.byteLength(full.stdout),elapsed_ms});
  });
}
// Controlled changes in real Random input: these are not upstream releases.
for(const [label,file,before,after]of[
  ['list-payload','random.wit','get-random-bytes: func(len: u64) -> list<u8>;','get-random-bytes: func(len: u64) -> list<u16>;'],
  ['tuple-payload','insecure-seed.wit','tuple<u64, u64>','tuple<u32, u64>'],
]){
  const mutation=path.join(output,'mutations',label);fs.cpSync(source('random','0.2.0'),mutation,{recursive:true});
  const target=path.join(mutation,file),text=fs.readFileSync(target,'utf8');assert.equal(text.split(before).length,2,'Unique mutation anchor');fs.writeFileSync(target,text.replace(before,after));
  save(label+'-mutation',{kind:'controlled mutation, not an upstream release',file,before,after});
  const oracle=path.join(output,'oracle/random');
  const version=label==='list-payload'?'0.2.98':'0.2.99';
  const dest=path.join(oracle,'deps','mutated-'+label);fs.cpSync(mutation,dest,{recursive:true});
  for(const name of fs.readdirSync(dest))if(name.endsWith('.wit')){const f=path.join(dest,name);fs.writeFileSync(f,fs.readFileSync(f,'utf8').replaceAll('wasi:random@0.2.0','wasi:random@'+version));}
  for(const direction of ['provider-upgrade','consumer-upgrade'])test(`real ${label} change ${direction}`,()=>{
    const r=compare(source('random','0.2.0'),mutation,'imports','imports',direction);save(label+'-'+direction,r);
    assert.equal(r.status,'BREAKING');assert(r.findings.some(f=>f.rule_id==='TYPE_CHANGED'));
    const actual=direction==='provider-upgrade'?version:'0.2.0',expected=direction==='provider-upgrade'?'0.2.0':version;
    official(label+'-reference-'+direction,['component','semver-check',oracle,'--prev',`wasi:random/imports@${actual}`,'--new',`wasi:random/imports@${expected}`],1);
  });
}
test('all original upstream source bytes preserved',()=>{
  for(const entry of manifest)for(const file of entry.files)assert.equal(digest(path.join(corpus,entry.label,file.path)),file.sha256);
});
const summary={status:rows.every(r=>r.status==='PASS')?'PASS':'FAIL',total:rows.length,passed:rows.filter(r=>r.status==='PASS').length,
  corpus,source_manifest:manifest.map(({label,repository,commit,archive_sha256})=>({label,repository,commit,archive_sha256})),
  metrics,remote_ci:'NOT_RUN',native:'NOT_RUN',tests:rows};
save('summary',summary);console.log(`Real-project checks: ${summary.passed}/${summary.total}; ${output}`);
for(const r of rows.filter(r=>r.status==='FAIL'))console.error(r.name+'\n'+r.error);
process.exitCode=summary.status==='PASS'?0:1;
