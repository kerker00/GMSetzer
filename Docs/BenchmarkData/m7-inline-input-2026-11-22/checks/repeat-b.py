from pathlib import Path
import subprocess
p=Path(__file__).resolve().parent
for label,binary,cwd in [('repeat-before',p/'before-mac',Path('<BASELINE_ROOT>')),('repeat-after',Path('/private/tmp/gmsetzer-m7-benchmark-build/arm64-apple-macosx/release'),Path('<SOURCE_ROOT>'))]:
 with (p/(label+'.stdout')).open('wb') as o,(p/(label+'.stderr')).open('wb') as e: r=subprocess.run(['python3',str(p/'repeat.py'),label,str(binary)],cwd=cwd,stdout=o,stderr=e,timeout=500)
 r.check_returncode();print(label,'passed',flush=True)
