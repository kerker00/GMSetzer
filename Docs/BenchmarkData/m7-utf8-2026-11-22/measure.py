import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import time

root = Path.cwd()
task = Path(__file__).parent
label = sys.argv[1]
binary = Path(sys.argv[2])
spec = importlib.util.spec_from_file_location('driver', root / 'Tools/run_hardening_benchmarks.py')
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)
out = task / label
out.mkdir(exist_ok=False)
files = driver.measurement_files(root) + [root / 'Tools/Benchmarks/UTF8Benchmarks/UTF8Benchmarks.swift']
receipt = dict(label=label, started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
               load_before=os.getloadavg(), source_sha256={str(p.relative_to(root)):driver.digest(p) for p in files},
               binary_sha256={p.name:driver.digest(p) for p in binary.iterdir() if p.is_file()},
               scope='Separate unprofiled direct subsets; unchanged cases/limits; no SwiftPM parent.', targets={})
targets = [('UTF8Benchmarks', r'(GMSetzer .* parse syntax-(off|on)|cmark-gfm \(C\) .* parse validation-(off|on)) (16|64|256) KiB',36,240)]

def save():
    (out / 'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
save()
for target,pattern,count,timeout in targets:
    command = [str(binary/'BenchmarkTool'),'--command','run','--baseline-storage-path',str(out),
               '--format','markdown','--grouping','benchmark','--time-units','microseconds','--no-progress',
               '--targets',target,'--benchmark-executable-paths',str(binary/target),'--filter',pattern]
    stdout,stderr=out/(target+'.md'),out/(target+'.stderr')
    code,timed_out=driver.execute(command,stdout,stderr,timeout)
    phase=dict(exit_code=code,timed_out=timed_out,stdout_sha256=driver.digest(stdout),stderr_sha256=driver.digest(stderr))
    receipt['targets'][target]=phase
    save()
    assert not code and not timed_out,(target,phase)
    blocks=re.split(r'(?m)^### ',stdout.read_text())[1:]
    names=[block.splitlines()[0] for block in blocks]
    assert len(names)==len(set(names))==count,(target,names)
    assert all(re.fullmatch(pattern,name.split(' (bytes: ',1)[0]) for name in names)
    phase['cases']=[dict(name=name,**driver.parse_result('### '+block,name)) for name,block in zip(names,blocks)]
    print(label,target,count,'complete',flush=True)
    save()
for name,expected in receipt['source_sha256'].items():assert driver.digest(root/name)==expected,name
for name,expected in receipt['binary_sha256'].items():assert driver.digest(binary/name)==expected,name
receipt.update(status='complete',finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),load_after=os.getloadavg())
save()
