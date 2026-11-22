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
files = driver.measurement_files(root) + [root / 'Tools/Benchmarks/ParserBenchmarks/ParserBenchmarks.swift', root / 'Tools/Benchmarks/UTF8Benchmarks/UTF8Benchmarks.swift']
receipt = dict(label=label, started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
               load_before=os.getloadavg(), source_sha256={str(p.relative_to(root)):driver.digest(p) for p in files},
               binary_sha256={p.name:driver.digest(p) for p in binary.iterdir() if p.is_file()},
               scope='Separate unprofiled direct subsets; unchanged cases/limits; no SwiftPM parent.', targets={})
targets = [('UTF8Benchmarks',r'.*',36,300),('HardeningBenchmarks',r'.*',69,600),('ParserBenchmarks',r'.*',72,600)]


# Read-only editor queries can legitimately allocate nothing. Timing and
# allocation units/sample counts remain mandatory, finite and nonnegative.
def full_result(text, expected):
    from decimal import Decimal
    assert re.findall(r"^### (.+)$", text, re.MULTILINE) == [expected]
    metrics = {}
    for line in text.splitlines():
        if not line.startswith("|"): continue
        cells = [value.strip() for value in line.strip("|").split("|")]
        if not cells[0].startswith(("Time (wall clock)", "Malloc (total)", "Malloc (bytes total)")): continue
        assert len(cells) == 9 and cells[0] not in metrics
        value, samples = Decimal(cells[3]), int(cells[8])
        assert value.is_finite() and value >= 0 and samples > 0
        if cells[0].startswith("Time"): assert value > 0 and "(μs)" in cells[0]
        metrics[cells[0]] = dict(p50_display=cells[3], samples=samples)
    assert len(metrics) == 3
    for prefix in ["Time (wall clock)", "Malloc (total)", "Malloc (bytes total)"]:
        assert sum(name.startswith(prefix) for name in metrics) == 1
    timing = next(v for k,v in metrics.items() if k.startswith("Time"))
    return dict(wall_ms_p50=str(Decimal(timing['p50_display'])/1000), metrics=metrics)

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
    phase['cases']=[dict(name=name,**full_result('### '+block,name)) for name,block in zip(names,blocks)]
    print(label,target,count,'complete',flush=True)
    save()
for name,expected in receipt['source_sha256'].items():assert driver.digest(root/name)==expected,name
for name,expected in receipt['binary_sha256'].items():assert driver.digest(binary/name)==expected,name
receipt.update(status='complete',finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),load_after=os.getloadavg())
save()
