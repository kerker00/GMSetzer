from pathlib import Path
import json,subprocess,time
p=Path(__file__).resolve().parent;deadline=time.monotonic()+3600
while True:
 r=json.loads((p/'native-b-matrices.json').read_text())
 if r.get('status')=='passed':break
 if any(x['exit_code'] or x['timed_out'] for x in r['phases'].values()):raise RuntimeError('Main native sequence failed')
 if time.monotonic()>deadline:raise TimeoutError('Main sequence did not complete')
 time.sleep(30)
# Reverse variant order relative to the first full pair; no own measurement
# competes with either variant. Before sources remain in the old source root.
for label,binary,root in [('native-repeat-after',Path('<NATIVE_CACHE>/GMSetzer/build-tools/x86_64-unknown-linux-gnu/release'),p/'GMSetzer'),('native-repeat-before',p/'before',Path('<BASELINE_NATIVE_ROOT>'))]:
 with (p/(label+'.stdout')).open('wb') as o,(p/(label+'.stderr')).open('wb') as e:r=subprocess.run(['python3',str(p/'run-focused.py'),label,str(binary)],cwd=root,stdout=o,stderr=e,timeout=300)
 r.check_returncode();print(label,'passed',flush=True)
