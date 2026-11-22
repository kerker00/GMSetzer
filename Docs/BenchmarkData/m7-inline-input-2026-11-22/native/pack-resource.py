from pathlib import Path
import csv,hashlib,json,tarfile
p=Path(__file__).resolve().parent;d=p/'resource-after';rows=json.loads((d/'summary.json').read_text());assert len(rows)==42
columns=['case','source_bytes','parse_ms_p50','full_ms_p50','first_ready_ms_p50','all_groups_ms_p50']
with (d/'summary.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=columns,lineterminator='\n',extrasaction='ignore');w.writeheader();w.writerows(rows)
count=0
with tarfile.open(d/'raw-results.tar.gz','w:gz') as archive:
 for row in rows:
  for f in sorted((d/row['case']).glob('*.json')):
   info=archive.gettarinfo(str(f),arcname='results/'+row['case']+'/'+f.name);info.uid=info.gid=info.mtime=0;info.uname=info.gname=''
   with f.open('rb') as stream:archive.addfile(info,stream)
   count+=1
assert count==756,count
files=['raw-results.tar.gz','receipt.json','summary.csv','summary.json'];(d/'sha256.json').write_text(json.dumps({name:hashlib.sha256((d/name).read_bytes()).hexdigest() for name in files},indent=2)+'\n');print('Packed',count,'raw resource records')
