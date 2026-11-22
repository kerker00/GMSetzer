import hashlib,importlib.util,json,os,platform,re,sys,time
from pathlib import Path
root=Path.cwd(); task=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("driver",root/"Tools/run_hardening_benchmarks.py"); d=importlib.util.module_from_spec(spec); spec.loader.exec_module(d)
label,binary=sys.argv[1],Path(sys.argv[2]); out=task/label; out.mkdir()
files=d.measurement_files(root)+[root/"Tools/Benchmarks/ParserBenchmarks/ParserBenchmarks.swift",root/"Tools/Benchmarks/UTF8Benchmarks/UTF8Benchmarks.swift"]
r={"label":label,"started_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"source_sha256":{str(p.relative_to(root)):d.digest(p) for p in files},"binary_sha256":{p.name:d.digest(p) for p in binary.iterdir() if p.is_file()},"load_before":os.getloadavg(),"host":platform.platform()}
cmd=[str(binary/"BenchmarkTool"),"--command","run","--baseline-storage-path",str(out),"--format","markdown","--grouping","benchmark","--time-units","microseconds","--no-progress","--targets","ParserBenchmarks","--benchmark-executable-paths",str(binary/"ParserBenchmarks")]
r["command"]=cmd
(out/"receipt.json").write_text(json.dumps(r,indent=2)+"\n")
code,timeout=d.execute(cmd,out/"results.md",out/"stderr",900);r.update(exit_code=code,timed_out=timeout)
assert code==0 and not timeout,r
blocks=re.split(r"(?m)^### ",(out/"results.md").read_text())[1:]; names=[b.splitlines()[0] for b in blocks];assert len(names)==len(set(names))==72,len(names)
r["cases"]=[dict(name=n,**d.parse_result("### "+b,n)) for n,b in zip(names,blocks)]
for n,h in r["source_sha256"].items(): assert d.digest(root/n)==h,n
for n,h in r["binary_sha256"].items(): assert d.digest(binary/n)==h,n
r.update(status="passed",finished_utc=time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),load_after=os.getloadavg());(out/"receipt.json").write_text(json.dumps(r,indent=2)+"\n");print(label,72,"cases passed",flush=True)
