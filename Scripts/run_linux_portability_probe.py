#!/usr/bin/env python3
"""Run a prebuilt static ARM64 probe in a temporary, network-free QEMU guest."""

import argparse
import gzip
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kernel', type=Path, required=True)
    parser.add_argument('--initramfs', type=Path, required=True)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--fixtures', type=Path, required=True)
    parser.add_argument('--log', type=Path, required=True)
    parser.add_argument('--qemu', default='qemu-system-aarch64')
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    for path in [args.kernel, args.initramfs, args.binary]:
        if not path.is_file():
            parser.error('missing file: ' + str(path))
    args.log.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='gmsetzer-linux-') as directory:
        root = Path(directory) / 'guest'
        root.mkdir()
        # Inputs are trusted Alpine netboot artifacts; no package is installed
        # on the host and no host filesystem is shared with the guest.
        with gzip.open(args.initramfs, 'rb') as source:
            subprocess.run(['cpio', '-idm'], cwd=root, input=source.read(), check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        shutil.copy2(args.binary, root / 'probe')
        (root / 'fixtures').mkdir(exist_ok=True)
        for name in ['baseline.json', 'commonmark-0.31.2.json', 'gfm-0.29.json']:
            shutil.copy2(args.fixtures / name, root / 'fixtures' / name)
        (root / 'init').unlink()
        (root / 'init').write_text('''#!/bin/sh
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t devtmpfs devtmpfs /dev
/bin/busybox mkdir -p /tmp
/bin/busybox uname -a
/probe /fixtures
result=$?
echo GMSETZER_LINUX_EXIT=$result
/bin/busybox poweroff -f
''')
        (root / 'init').chmod(0o755)
        entries = ['.']
        for folder, dirs, files in os.walk(root, followlinks=False):
            base = Path(folder).relative_to(root)
            entries.extend(str(base / name) for name in sorted(dirs + files))
        archive = Path(directory) / 'guest.cpio'
        with archive.open('wb') as output:
            subprocess.run(['cpio', '-0', '-o', '-H', 'newc'], cwd=root,
                           input=('\0'.join(entries) + '\0').encode(), stdout=output,
                           stderr=subprocess.PIPE, check=True)
        compressed = Path(directory) / 'guest.cpio.gz'
        with archive.open('rb') as source, gzip.open(compressed, 'wb', compresslevel=1) as output:
            shutil.copyfileobj(source, output)
        command = [args.qemu, '-machine', 'virt', '-cpu', 'cortex-a72', '-accel', 'tcg',
                   '-m', '1536', '-smp', '2', '-nographic', '-monitor', 'none', '-nic', 'none',
                   '-no-reboot', '-kernel', str(args.kernel.resolve()), '-initrd', str(compressed),
                   '-append', 'console=ttyAMA0 rdinit=/init panic=-1']
        with args.log.open('wb') as output:
            result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=args.timeout)
        text = args.log.read_text(errors='replace')
        print('\n'.join(text.splitlines()[-10:]))
        if result.returncode != 0 or 'GMSETZER_LINUX_EXIT=0' not in text or 'PORTABILITY_PROBE_PASSED' not in text:
            raise SystemExit('Linux probe did not complete successfully; inspect ' + str(args.log))


if __name__ == '__main__':
    main()
