"""Run an actual dedicated server and ENet client for each new arena on loopback.

Uses the existing Godot modes_client harness. No player progress files are touched.
Usage: python tools/test_arenas_network.py [path/to/godot_console.exe]
"""
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
GODOT = sys.argv[1] if len(sys.argv) > 1 else str(Path.home() / 'Godot/Godot_v4.7.2-stable_win64_console.exe')


def main():
    with tempfile.TemporaryDirectory(prefix='giera-network-') as temp:
        for i, arena in enumerate(['neonowa_dzielnica', 'stacja_rdzen']):
            port = str(17841 + i)
            log = ROOT / 'tools' / (arena + '_network.tmp')
            with log.open('w', encoding='utf-8') as stream:
                server = subprocess.Popen([GODOT, '--headless', '--path', str(ROOT), '--', '--server',
                                           '--mode=pvp', '--map=' + arena, '--bots=6', '--limit=20',
                                           '--port=' + port, '--progress-file=' + temp + '/server.cfg'],
                                          stdout=stream, stderr=subprocess.STDOUT)
                try:
                    time.sleep(2)
                    result = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--', '--test=client',
                                             '--modes-check', '--want-mode=pvp', '--want-map=' + arena,
                                             '--seconds=40', '--port=' + port, '--join-wait=3',
                                             '--token=arena-' + str(i), '--progress-file=' + temp + '/client.cfg'],
                                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=65)
                    output = result.stdout.decode('utf-8', errors='replace')
                    print(output, flush=True)
                    if result.returncode or '[client] FAIL' in output or 'SCRIPT ERROR' in output or '[client] koniec: PASS' not in output:
                        raise RuntimeError('Network test failed: ' + arena)
                finally:
                    server.terminate()
                    server.wait(timeout=10)
            server_log = log.read_text(encoding='utf-8')
            if 'SCRIPT ERROR' in server_log or 'ERROR:' in server_log:
                raise RuntimeError('Server errors: ' + str(log))
            print('PASS network:', arena, flush=True)


if __name__ == '__main__':
    main()
