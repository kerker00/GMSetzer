import hashlib,json,os,subprocess,time
from pathlib import Path
p=Path(__file__).resolve().parent;root=Path.cwd();env=os.environ.copy();env['CLANG_MODULE_CACHE_PATH']='/private/tmp/gmsetzer-m7-module-cache';env['SWIFTPM_MODULECACHE_OVERRIDE']='/private/tmp/gmsetzer-m7-module-cache'
common=['--build-system','native','--disable-sandbox','--jobs','2','--cache-path','/private/tmp/gmsetzer-m7-cache','--config-path','/private/tmp/gmsetzer-m7-config','--security-path','/private/tmp/gmsetzer-m7-security'];bc=common.copy();bc[bc.index('/private/tmp/gmsetzer-m7-cache')]='/private/tmp/gmsetzer-m7-benchmark-cache';bin=Path('/private/tmp/gmsetzer-m7-benchmark-build/arm64-apple-macosx/release')
phases=[('mac-release-b',['swift','test','-c','release',*common,'--scratch-path',str(p/'release-build')]),('mac-tools-b',['swift','test','--package-path','Tools','-c','release',*bc,'--scratch-path','/private/tmp/gmsetzer-m7-benchmark-build','--skip-update','--force-resolved-versions','-debug-info-format','none']),('mac-benchmark-build-b',['swift','package','--package-path','Tools',*bc,'--scratch-path','/private/tmp/gmsetzer-m7-benchmark-build','--skip-update','--force-resolved-versions','-debug-info-format','none','benchmark','list','--target','ParserBenchmarks','--target','HardeningBenchmarks','--target','UTF8Benchmarks']),('mac-asan-b',['swift','test',*common,'--sanitize','address','--scratch-path',str(p/'asan-build')]),('mac-stress-build-b',['swift','build','--package-path','Tools/ParserStressProbe',*common,'--sanitize','address','--scratch-path',str(p/'stress-build')]),('mac-stress-b',[str(p/'stress-build/arm64-apple-macosx/debug/ParserStressProbe'),'1024']),('mac-parser-b',['python3',str(p/'run-parser.py'),'mac-parser-b',str(bin)]),('mac-m5-b',['python3',str(p/'measure-m5.py'),'mac-m5-b',str(bin)])]
r={'base':'e75567c','candidate':'B (fresh custom-rule projections)','phases':{}}
for label,command in phases:
 start=time.monotonic()
 with (p/(label+'.stdout')).open('wb') as out,(p/(label+'.stderr')).open('wb') as err:
  proc=subprocess.Popen(command,cwd=root,stdout=out,stderr=err,env=env,start_new_session=True)
  try:code=proc.wait(timeout=900 if label!='mac-stress-b' else 180)
  except subprocess.TimeoutExpired:
   __import__('signal');os.killpg(proc.pid,__import__('signal').SIGKILL);proc.wait();raise
 r['phases'][label]={'command':command,'exit_code':code,'elapsed_seconds':time.monotonic()-start};(p/'mac-b-validation.json').write_text(json.dumps(r,indent=2)+'\n');print(label,code,flush=True)
 if code:raise SystemExit(code)
r['status']='passed';(p/'mac-b-validation.json').write_text(json.dumps(r,indent=2)+'\n')
