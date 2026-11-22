import importlib.util,json,re,sys,os,time
from pathlib import Path
root=Path.cwd();task=Path(__file__).parent
spec=importlib.util.spec_from_file_location('driver',root/'Tools/run_hardening_benchmarks.py');driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)
label,binary=sys.argv[1],Path(sys.argv[2]);out=task/label;out.mkdir()
files=driver.measurement_files(root)+[root/'Tools/Benchmarks/ParserBenchmarks/ParserBenchmarks.swift',root/'Tools/Benchmarks/UTF8Benchmarks/UTF8Benchmarks.swift']
r=dict(label=label,started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),load_before=os.getloadavg(),source_sha256={str(p.relative_to(root)):driver.digest(p) for p in files},binary_sha256={p.name:driver.digest(p) for p in binary.iterdir() if p.is_file()},targets={})
def save():(out/'receipt.json').write_text(json.dumps(r,indent=2)+'\n')
save()
for target,pattern,count in [('HardeningBenchmarks',r'^GMSetzer (m5-composed-v1|footnotes-repeated-v1) (parse|parse-render) syntax-(off|on) 256 KiB$',8)]:
 cmd=[str(binary/'BenchmarkTool'),'--command','run','--baseline-storage-path',str(out),'--format','markdown','--grouping','benchmark','--time-units','microseconds','--no-progress','--targets',target,'--benchmark-executable-paths',str(binary/target),'--filter',pattern]
 stdout,stderr=out/(target+'.md'),out/(target+'.stderr');code,timeout=driver.execute(cmd,stdout,stderr,180)
 phase=dict(command=cmd,exit_code=code,timed_out=timeout,stdout_sha256=driver.digest(stdout),stderr_sha256=driver.digest(stderr));r['targets'][target]=phase;save();assert code==0 and not timeout,(target,phase)
 blocks=re.split(r'(?m)^### ',stdout.read_text())[1:];names=[b.splitlines()[0] for b in blocks];assert len(names)==len(set(names))==count
 assert all(re.fullmatch(pattern,n.split(' (bytes:',1)[0]) for n in names)
 phase['cases']=[dict(name=n,**driver.parse_result('### '+b,n)) for n,b in zip(names,blocks)];save();print(label,target,count,'complete',flush=True)
for name,h in r['source_sha256'].items():assert driver.digest(root/name)==h,name
for name,h in r['binary_sha256'].items():assert driver.digest(binary/name)==h,name
r.update(status='passed',finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),load_after=os.getloadavg());save()
