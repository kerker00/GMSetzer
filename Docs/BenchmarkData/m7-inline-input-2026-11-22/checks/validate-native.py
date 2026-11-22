import hashlib,json,subprocess,time,sys
from pathlib import Path
p=Path(__file__).resolve().parent;root=p/"GMSetzer";old=Path("<NATIVE_CACHE>/GMSetzer")
r={"status":"running","base":"e75567c349334841d0b481e403adc61d96758740","dirty":True,"phases":{}}
common=["--build-system","native","--disable-sandbox","--jobs","2","--cache-path",str(old/"cache"),"--config-path",str(old/"config"),"--security-path",str(old/"security")]
phases=[("debug",["swift","test",*common,"--scratch-path",str(old/"build-debug")]),("release",["swift","test","-c","release",*common,"--scratch-path",str(old/"build-release")]),("tools",["swift","test","--package-path","Tools","-c","release",*common,"--scratch-path",str(old/"build-tools"),"--skip-update","--force-resolved-versions","-debug-info-format","none"]),("benchmark-build",["swift","package","--package-path","Tools",*common,"--scratch-path",str(old/"build-tools"),"--skip-update","--force-resolved-versions","-debug-info-format","none","benchmark","list","--target","ParserBenchmarks","--target","HardeningBenchmarks","--target","UTF8Benchmarks"]),("comparison-build",["swift","build","--package-path","Tools","-c","release",*common,"--scratch-path",str(old/"build-tools"),"--skip-update","--force-resolved-versions","-debug-info-format","none","--product","ParserComparisonProbe"]),("probe",["swift","build","--package-path","Tools/ProgressiveHTMLProbe","-c","release",*common,"--scratch-path",str(old/"build-probe")])]
for label,command in phases:
 start=time.monotonic()
 with (p/(label+".stdout")).open("wb") as out,(p/(label+".stderr")).open("wb") as err: code=subprocess.run(command,cwd=root,stdout=out,stderr=err,timeout=900).returncode
 r["phases"][label]={"command":command,"exit_code":code,"elapsed_seconds":time.monotonic()-start};(p/"validation.json").write_text(json.dumps(r,indent=2)+"\n");print(label,code,flush=True)
 if code: sys.exit(code)
manifest=json.loads((p/"candidate-source.json").read_text())
assert all(hashlib.sha256((root/n).read_bytes()).hexdigest()==h for n,h in manifest.items())
r.update(status="passed",source_files=len(manifest),sources_unchanged=True);(p/"validation.json").write_text(json.dumps(r,indent=2)+"\n")
