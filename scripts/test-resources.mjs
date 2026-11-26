import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {compare} from '../witprobe.mjs';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const out=path.resolve(process.argv[2]??path.join(root,'work',`resource-tests-${Date.now()}`));
assert.match(out,/^D:\\/i);assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
const rows=[];
const env={...process.env,TEMP:path.join(root,'work/tmp'),TMP:path.join(root,'work/tmp'),TMPDIR:path.join(root,'work/tmp')};
const tool=path.join(root,'work/tools/wasm-tools-1.263.0-x86_64-windows/wasm-tools.exe');
function test(name,fn){try{fn();rows.push({name,status:'PASS'});}catch(e){rows.push({name,status:'FAIL',error:e.stack});}}
const cases=[
 ['constructor','resource file { constructor(size: u32); }','resource file { constructor(size: u64); }',1,1],
 ['method-result','resource file { read: func() -> u32; }','resource file { read: func() -> u64; }',1,1],
 ['static-result','resource file { open: static func() -> u32; }','resource file { open: static func() -> u64; }',1,1],
 ['ownership','resource file; f: func(x: own<file>);','resource file; f: func(x: borrow<file>);',1,1],
 ['nominal','resource file; resource socket; f: func(x: own<file>);','resource file; resource socket; f: func(x: own<socket>);',1,1],
 ['nested-own','resource file; f: func(x: list<option<own<file>>>);','resource file; f: func(x: list<option<borrow<file>>>);',1,1],
 ['add-method','resource file { read: func(); }','resource file { read: func(); write: func(); }',0,1],
 ['remove-resource','resource file; resource socket;','resource file;',1,0],
 ['alias-owner','resource file; resource socket; type alias = file; f: func(x: own<alias>);','resource file; resource socket; type alias = socket; f: func(x: own<alias>);',1,1],
];
function src(def,v,side='export'){return `package demo:handles@${v}; interface api { ${def} } world app { ${side} api; }\n`;}
let referenceCount=0;
for(const [name,a,b,p,c]of cases)for(const side of ['export','import']){
 const dir=path.join(out,name+'-'+side),old=path.join(dir,'old'),next=path.join(dir,'new'),oracle=path.join(dir,'oracle');
 fs.mkdirSync(old,{recursive:true});fs.mkdirSync(next);fs.writeFileSync(path.join(old,'world.wit'),src(a,'1.0.0',side));fs.writeFileSync(path.join(next,'world.wit'),src(b,'2.0.0',side));
 fs.mkdirSync(path.join(oracle,'deps'),{recursive:true});fs.cpSync(old,path.join(oracle,'deps/old'),{recursive:true});fs.cpSync(next,path.join(oracle,'deps/new'),{recursive:true});fs.writeFileSync(path.join(oracle,'world.wit'),'package validation:root; world root {}\n');
 test(name+' '+side+' unchanged',()=>assert.equal(compare(old,old,'app','app').status,'COMPATIBLE'));
 for(const [direction,base]of[['provider-upgrade',p],['consumer-upgrade',c]])test(name+' '+side+' '+direction,()=>{
  const expected=side==='export'?base:(direction==='provider-upgrade'?c:p);
  const r=compare(old,next,'app','app',direction);const actualV=direction==='provider-upgrade'?'2.0.0':'1.0.0',expectV=direction==='provider-upgrade'?'1.0.0':'2.0.0';
  const args=['component','semver-check',oracle,'--prev',`demo:handles/app@${actualV}`,'--new',`demo:handles/app@${expectV}`];
  const ref=spawnSync(tool,args,{env,encoding:'utf8',windowsHide:true,timeout:30000});referenceCount++;
  fs.writeFileSync(path.join(dir,direction+'.json'),JSON.stringify({report:r,reference:{args,exit:ref.status,stderr:ref.stderr,error:ref.error?.message??null}},null,2));
  assert(!ref.error);assert.equal(ref.status,expected);if(expected===1)assert.match(ref.stderr,/not semver-compatible/);assert.equal(r.exit_code,ref.status);
 });
}
const mappingRoot=path.join(out,'mappings');fs.mkdirSync(mappingRoot);
const old=path.join(mappingRoot,'old'),next=path.join(mappingRoot,'new');
for(const [dir,version]of[[old,'1.0.0'],[next,'2.0.0']]){fs.mkdirSync(path.join(dir,'deps/api'),{recursive:true});fs.writeFileSync(path.join(dir,'world.wit'),`package demo:root; world app { export dep:service/api@${version}; }\n`);fs.writeFileSync(path.join(dir,'deps/api/world.wit'),`package dep:service@${version}; interface api { resource file { read: func() -> u32; } f: func(x: own<file>); }\n`);}
const pair={old_package:'dep:service@1.0.0',new_package:'dep:service@2.0.0'};
const policy=packages=>({schema_version:1,packages});
test('dependency mapping is explicit and checked',()=>{
 assert.equal(compare(old,next,'app','app').status,'UNKNOWN');
 const r=compare(old,next,'app','app','provider-upgrade',policy([pair]));assert.equal(r.status,'COMPATIBLE');assert.equal(r.dependency_mappings.length,1);
 assert(r.markdown.includes(pair.new_package));assert(r.new_contract.exports[0].key.includes('@2.0.0'));assert(r.comparison_new_contract.exports[0].key.includes('@1.0.0'));
});
for(const [label,config]of[
 ['duplicate',[pair,pair]],['absent',[{...pair,new_package:'dep:service@3.0.0'}]],['cross-package',[{...pair,new_package:'other:service@2.0.0'}]],['wrong-direction',[{old_package:pair.new_package,new_package:pair.old_package}]],['same-version',[{...pair,new_package:pair.old_package}]],
])test('reject mapping '+label,()=>{const r=compare(old,next,'app','app','provider-upgrade',policy(config));assert.equal(r.status,'ERROR');assert.equal(r.error.code,'DEPENDENCY_MAPPING_ERROR');});
for(const [label,config]of[
 ['unknown-field',{...policy([pair]),ignore_all_versions:true}],['duplicate-json-key','{"schema_version":1,"schema_version":1,"packages":[]}'],['invalid-json','{oops'],
])test('reject '+label,()=>assert.equal(compare(old,next,'app','app','provider-upgrade',config).error.code,'DEPENDENCY_MAPPING_ERROR'));
test('reject root remapping',()=>{
 const r=compare(path.join(out,'constructor-export/old'),path.join(out,'constructor-export/new'),'app','app','provider-upgrade',policy([{old_package:'demo:handles@1.0.0',new_package:'demo:handles@2.0.0'}]));assert.equal(r.error.code,'DEPENDENCY_MAPPING_ERROR');
});
test('reject merging coexisting package versions',()=>{
 const both=path.join(mappingRoot,'coexisting');fs.cpSync(next,both,{recursive:true});fs.cpSync(path.join(old,'deps/api'),path.join(both,'deps/old'),{recursive:true});
 fs.writeFileSync(path.join(both,'world.wit'),'package demo:root; world app { export dep:service/api@1.0.0; export dep:service/api@2.0.0; }');
 assert.equal(compare(old,both,'app','app','provider-upgrade',policy([pair])).error.code,'DEPENDENCY_MAPPING_ERROR');
});
test('mapping cannot hide a resource method break',()=>{
 const broken=path.join(mappingRoot,'broken');fs.cpSync(next,broken,{recursive:true});const f=path.join(broken,'deps/api/world.wit');fs.writeFileSync(f,fs.readFileSync(f,'utf8').replace('-> u32','-> u64'));
 for(const d of ['provider-upgrade','consumer-upgrade'])assert.equal(compare(old,broken,'app','app',d,policy([pair])).status,'BREAKING');
});
const summary={status:rows.every(r=>r.status==='PASS')?'PASS':'FAIL',total:rows.length,passed:rows.filter(r=>r.status==='PASS').length,official_differential:referenceCount,tests:rows};
fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify(summary,null,2)+'\n');console.log(`Resources/mapping checks: ${summary.passed}/${summary.total}; official ${referenceCount}; ${out}`);for(const r of rows.filter(r=>r.status==='FAIL'))console.error(r.name+'\n'+r.error);process.exitCode=summary.status==='PASS'?0:1;
