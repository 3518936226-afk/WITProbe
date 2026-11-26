import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {compare,createBaseline,regression} from '../witprobe.mjs';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const corpus=path.resolve(process.argv[2]??'');const out=path.resolve(process.argv[3]??'');assert(process.argv[2]&&process.argv[3]);assert.match(out,/^D:\\/i);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));const manifest=read(path.join(corpus,'../corpus-manifest.json'));
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function verify(){for(const e of manifest)for(const f of e.files)assert.equal(sha(path.join(corpus,e.label,f.path)),f.sha256);}
verify();const old=path.join(corpus,'wasi-cli-v0.2.0/wit'),next=path.join(corpus,'wasi-cli-v0.2.1/wit');const policy=read(path.join(root,'fixtures/wasi-cli-0.2.0-to-0.2.1.mapping.json'));
const tool=path.join(root,'work/tools/wasm-tools-1.263.0-x86_64-windows/wasm-tools.exe');const env={...process.env,TEMP:path.join(root,'work/tmp'),TMP:path.join(root,'work/tmp'),TMPDIR:path.join(root,'work/tmp')};
const rows=[];function test(name,fn){try{fn();rows.push({name,status:'PASS'});}catch(e){rows.push({name,status:'FAIL',error:e.stack});}}
const baseline=path.join(out,'baseline');createBaseline(old,'command',baseline);
const specs=[
 ['ownership','src: borrow<input-stream>,','src: own<input-stream>,'],
 ['nominal-resource','src: borrow<input-stream>,','src: borrow<output-stream>,'],
 ['method-result','check-write: func() -> result<u64, stream-error>;','check-write: func() -> result<u32, stream-error>;'],
 ['method-rename','splice: func(','splice-renamed: func('],
];
for(const [label,before,after]of specs){
 const dir=path.join(out,label),mutated=path.join(dir,'mutated');fs.cpSync(next,mutated,{recursive:true});const f=path.join(mutated,'deps/io/streams.wit'),text=fs.readFileSync(f,'utf8');assert(text.includes(before),'Mutation anchor missing');fs.writeFileSync(f,text.replace(before,after));
 fs.writeFileSync(path.join(dir,'mutation.json'),JSON.stringify({kind:'controlled change in a real release copy, not an upstream bug or release',file:'deps/io/streams.wit',before,after,occurrences_before:text.split(before).length-1,replaced_occurrences:1},null,2));
 const oracle=path.join(dir,'oracle');fs.mkdirSync(path.join(oracle,'deps'),{recursive:true});
 for(const [src,version]of[[old,'0.2.0'],[mutated,'0.2.1']]){
  const pkg=path.join(oracle,'deps/cli-'+version);fs.mkdirSync(pkg);for(const e of fs.readdirSync(src,{withFileTypes:true}))if(e.isFile()&&e.name.endsWith('.wit'))fs.copyFileSync(path.join(src,e.name),path.join(pkg,e.name));
  for(const e of fs.readdirSync(path.join(src,'deps'),{withFileTypes:true}))if(e.isDirectory())fs.cpSync(path.join(src,'deps',e.name),path.join(oracle,'deps',e.name+'-'+version),{recursive:true});
 }
 fs.writeFileSync(path.join(oracle,'world.wit'),'package validation:root; world root {}\n');
 for(const direction of ['provider-upgrade','consumer-upgrade'])test(label+' '+direction,()=>{
  const r=compare(old,mutated,'command','command',direction,policy);assert.equal(r.status,'BREAKING');assert.equal(r.dependency_mappings.length,5);
  const reg=regression(baseline,mutated,undefined,direction,policy);assert.equal(reg.exit_code,1);
  const actual=direction==='provider-upgrade'?'0.2.1':'0.2.0',expected=direction==='provider-upgrade'?'0.2.0':'0.2.1';
  const args=['component','semver-check',oracle,'--prev',`wasi:cli/command@${actual}`,'--new',`wasi:cli/command@${expected}`];
  const ref=spawnSync(tool,args,{env,encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:32*1024*1024});
  fs.writeFileSync(path.join(dir,direction+'.json'),JSON.stringify({status:r.status,exit:r.exit_code,summary:r.summary,findings:r.findings,dependency_mappings:r.dependency_mappings,mapping_sha256:r.mapping_sha256,regression_exit:reg.exit_code,reference:{args,exit:ref.status,stderr:ref.stderr,error:ref.error?.message??null}},null,2));
  assert(!ref.error);assert.equal(ref.status,1);assert.match(ref.stderr,/not semver-compatible/);
 });
}
test('original source bytes preserved',verify);
const summary={status:rows.every(r=>r.status==='PASS')?'PASS':'FAIL',total:rows.length,passed:rows.filter(r=>r.status==='PASS').length,official_differential:8,policy,tests:rows};fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify(summary,null,2)+'\n');console.log(`Real WASI CLI resource break checks: ${summary.passed}/${summary.total}; ${out}`);for(const r of rows.filter(r=>r.status==='FAIL'))console.error(r.name+'\n'+r.error);process.exitCode=summary.status==='PASS'?0:1;
