import hashlib,importlib.util,json,os,platform,re,sys,time
from decimal import Decimal
from pathlib import Path
root=Path.cwd(); task=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("driver",root/"Tools/run_hardening_benchmarks.py"); d=importlib.util.module_from_spec(spec); spec.loader.exec_module(d)
def parse_case(block, name):
    metrics={}
    for line in block.splitlines():
        if not line.startswith("|"): continue
        cells=[c.strip() for c in line.strip("|").split("|")]
        if not cells[0].startswith(("Time (wall clock)","Malloc (total)","Malloc (bytes total)")): continue
        assert len(cells)==9 and cells[0] not in metrics
        value,samples=Decimal(cells[3]),int(cells[8]); assert value.is_finite() and samples>0
        assert value>0 if cells[0].startswith("Time") else value>=0
        metrics[cells[0]]={"p50_display":cells[3],"samples":samples}
    assert len(metrics)==3
    times=[v for n,v in metrics.items() if n.startswith("Time (wall clock) (μs)")];assert len(times)==1
    return {"wall_ms_p50":str(Decimal(times[0]["p50_display"])/1000),"metrics":metrics}
label,binary=sys.argv[1],Path(sys.argv[2]); out=task/label; out.mkdir()
files=d.measurement_files(root)+[root/"Tools/Benchmarks/ParserBenchmarks/ParserBenchmarks.swift",root/"Tools/Benchmarks/UTF8Benchmarks/UTF8Benchmarks.swift"]
r={"label":label,"started_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"source_sha256":{str(p.relative_to(root)):d.digest(p) for p in files},"binary_sha256":{p.name:d.digest(p) for p in binary.iterdir() if p.is_file()},"load_before":os.getloadavg(),"host":platform.platform()}
cmd=[str(binary/"BenchmarkTool"),"--command","run","--baseline-storage-path",str(out),"--format","markdown","--grouping","benchmark","--time-units","microseconds","--no-progress","--targets","UTF8Benchmarks","--benchmark-executable-paths",str(binary/"UTF8Benchmarks")]
r["command"]=cmd
(out/"receipt.json").write_text(json.dumps(r,indent=2)+"\n")
code,timeout=d.execute(cmd,out/"results.md",out/"stderr",900);r.update(exit_code=code,timed_out=timeout)
assert code==0 and not timeout,r
blocks=re.split(r"(?m)^### ",(out/"results.md").read_text())[1:]; names=[b.splitlines()[0] for b in blocks];assert len(names)==len(set(names))==36,len(names)
r["cases"]=[dict(name=n,**parse_case("### "+b,n)) for n,b in zip(names,blocks)]
for n,h in r["source_sha256"].items(): assert d.digest(root/n)==h,n
for n,h in r["binary_sha256"].items(): assert d.digest(binary/n)==h,n
r.update(status="passed",finished_utc=time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),load_after=os.getloadavg());(out/"receipt.json").write_text(json.dumps(r,indent=2)+"\n");print(label,36,"cases passed",flush=True)
