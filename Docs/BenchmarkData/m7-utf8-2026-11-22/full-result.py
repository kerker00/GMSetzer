
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

