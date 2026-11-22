"""Derive tables: RAW_DIRECTORY NEW_OUTPUT_DIRECTORY [ARTIFACT_MANIFEST]."""

import csv
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import re
import sys

folder = Path(sys.argv[1])
output = Path(sys.argv[2])
receipt = json.loads((folder / 'receipt.json').read_text())
retained = {}
if len(sys.argv) > 3:
    retained = {item['member']: item for item in json.loads(Path(sys.argv[3]).read_text())['members']}
assert receipt['status'] == 'complete' and receipt['cases_completed'] == 69
assert receipt['working_tree_status'] == []
output.mkdir(parents=True, exist_ok=False)
pattern = re.compile(r'(?P<engine>GMSetzer|cmark-gfm \(C\)) (?P<corpus>[\w-]+) '
                     r'(?P<operation>parse(?:-render)?)(?: syntax-(?P<syntax>on|off))? '
                     r'(?P<nominal>16|64|256) KiB \(bytes: (?P<bytes>\d+), '
                     r'corpus: (?P=corpus), profile: (?P<profile>[\w-]+), syntax: (?P<tag_syntax>on|off)\)')
def allocation(metrics, prefix):
    pairs = [(key, value) for key, value in metrics.items() if key.startswith(prefix)]
    assert len(pairs) == 1
    key, value = pairs[0]
    suffix = key[len(prefix):]
    match = re.fullmatch(r'(?: \(([KMGT])\))? \*', suffix)
    assert match is not None, key
    factor = {None:1, 'K':1000, 'M':1000000, 'G':1000000000, 'T':1000000000000}[match[1]]
    return key, value['p50_display'], int(Decimal(value['p50_display']) * factor)

rows = []
for case in receipt['cases']:
    assert case['status'] == 'complete' and case['exit_code'] == 0 and not case['timed_out']
    match = pattern.fullmatch(case['name'])
    assert match is not None, case['name']
    fields = match.groupdict()
    assert (fields['syntax'] or 'off') == fields['tag_syntax']
    count = allocation(case['metrics'], 'Malloc (total)')
    volume = allocation(case['metrics'], 'Malloc (bytes total)')
    samples = {value['samples'] for value in case['metrics'].values()}
    assert len(samples) == 1
    for suffix, key in [('md', 'stdout_sha256'), ('stderr', 'stderr_sha256')]:
        name = 'case-%03d.' % case['ordinal'] + suffix
        actual = hashlib.sha256((folder / name).read_bytes()).hexdigest()
        if actual != case[key]:
            # Sanitized exports retain an explicit mapping to original hashes.
            item = retained[name]
            assert item['original_sha256'] == case[key]
            assert item['retained_sha256'] == actual
    rows.append(dict(name=case['name'], engine=fields['engine'], corpus=fields['corpus'],
                     operation=fields['operation'], syntax=fields['tag_syntax'],
                     profile=fields['profile'], nominal_kib=int(fields['nominal']),
                     actual_bytes=int(fields['bytes']), wall_ms_p50=case['wall_ms_p50'],
                     samples=samples.pop(), malloc_count_metric=count[0], malloc_count_display=count[1],
                     malloc_count_approx=count[2], malloc_volume_metric=volume[0],
                     malloc_volume_display=volume[1], malloc_bytes_approx=volume[2]))
assert len(rows) == len({row['name'] for row in rows}) == 69

def csvfile(name, values):
    with (output / name).open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(values[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(values)

csvfile('summary.csv', rows)
groups = {}
for row in rows:
    key = tuple(row[x] for x in ('engine', 'corpus', 'operation', 'syntax'))
    groups.setdefault(key, []).append(row)
scaling = []
for key, group in groups.items():
    small, medium, large = sorted(group, key=lambda row: row['actual_bytes'])
    assert [row['nominal_kib'] for row in (small, medium, large)] == [16, 64, 256]
    result = dict(zip(('engine','corpus','operation','syntax'),key))
    result.update(small_bytes=small['actual_bytes'], large_bytes=large['actual_bytes'],
                  byte_growth=large['actual_bytes']/small['actual_bytes'],
                  small_ms=float(small['wall_ms_p50']), medium_ms=float(medium['wall_ms_p50']),
                  large_ms=float(large['wall_ms_p50']),
                  time_growth=float(large['wall_ms_p50'])/float(small['wall_ms_p50']),
                  count_growth=large['malloc_count_approx']/small['malloc_count_approx'],
                  gross_byte_growth=large['malloc_bytes_approx']/small['malloc_bytes_approx'],
                  small_gross_bytes_approx=small['malloc_bytes_approx'],
                  large_gross_bytes_approx=large['malloc_bytes_approx'])
    scaling.append(result)
assert len(scaling) == 23
csvfile('scaling.csv', scaling)
index = {(r['engine'],r['corpus'],r['operation'],r['syntax'],r['nominal_kib']):r for r in rows}
annotation = []
controls = []
for row in rows:
    if row['engine'] == 'GMSetzer' and row['syntax'] == 'on':
        plain = index[('GMSetzer',row['corpus'],row['operation'],'off',row['nominal_kib'])]
        annotation.append(dict(corpus=row['corpus'],operation=row['operation'],
                               nominal_kib=row['nominal_kib'],actual_bytes=row['actual_bytes'],
                               off_ms=float(plain['wall_ms_p50']),on_ms=float(row['wall_ms_p50']),
                               time_on_over_off=float(row['wall_ms_p50'])/float(plain['wall_ms_p50']),
                               count_on_over_off=row['malloc_count_approx']/plain['malloc_count_approx'],
                               bytes_on_over_off=row['malloc_bytes_approx']/plain['malloc_bytes_approx']))
    if row['engine'] == 'cmark-gfm (C)':
        swift = index[('GMSetzer',row['corpus'],'parse','off',row['nominal_kib'])]
        assert swift['actual_bytes'] == row['actual_bytes']
        controls.append(dict(corpus=row['corpus'],nominal_kib=row['nominal_kib'],actual_bytes=row['actual_bytes'],
                             swift_ms=float(swift['wall_ms_p50']),c_ms=float(row['wall_ms_p50']),
                             swift_over_c=float(swift['wall_ms_p50'])/float(row['wall_ms_p50']),
                             scope='Informational; quote/invalid-byte policies can differ; no new budget gate.'))
assert len(annotation) == 27 and len(controls) == 15
csvfile('annotation.csv',annotation)
csvfile('c-controls.csv',controls)
(output/'analysis.json').write_text(json.dumps(dict(
    schema=1, case_count=69, scaling_groups=23, annotation_pairs=27, c_control_pairs=15,
    formulas='Endpoint growth = large/small, using actual bytes; K/M/G = decimal 1000 powers. Allocation values are rounded display-derived approximations, not RSS.',
    scaling=scaling, annotation=annotation, c_controls=controls),indent=2)+'\n')
for row in scaling:
    print(row['engine'],row['corpus'],row['operation'],row['syntax'],
          '%.3f / %.3f / %.3f ms; time %.2fx, input %.2fx; gross %d -> %d' % (
              row['small_ms'],row['medium_ms'],row['large_ms'],row['time_growth'],row['byte_growth'],
              row['small_gross_bytes_approx'],row['large_gross_bytes_approx']))
