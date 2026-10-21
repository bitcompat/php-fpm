"""Run: python3 tests/test_image.py IMAGE PHP_VERSION (requires Docker)."""
import json
import subprocess
import sys

image, version = sys.argv[1:]
def run(*args):
    return subprocess.run(['docker', 'run', '--rm', '--entrypoint', '/bin/sh', image,
                           *args], capture_output=True, text=True, check=True).stdout

sbom = json.loads(run('-c', 'cat /opt/bitnami/php/.spdx-php.json'))
assert sbom['spdxVersion'] == 'SPDX-2.3' and sbom['packages']
assert 'Broadcom' not in str(sbom['creationInfo'])
assert any(p['name'] == 'bitcompat-php' and p.get('versionInfo') == version
           for p in sbom['packages'])
for name in ['php-cli', 'php-fpm']:
    assert any(p['name'] == name and p.get('versionInfo') == version
               for p in sbom['packages'])
run('-ec', '''
test -z "$(find / -xdev -type f -perm /6000 -print -quit)"
test -z "$(find /opt/bitnami/php/licenses -type f ! -perm 0644 -print -quit)"
test -L /opt/bitnami/php/.spdx-php.json
test "$(readlink /opt/bitnami/php/.spdx-php.json)" = /opt/bitnami/php/.spdx-php.spdx
test "$(stat -c %a /opt/bitnami/php/.spdx-php.spdx)" = 644
test ! -e /usr/local/bin/syft
test ! -d /tmp/syft-home/cache
php -n -r 'exit(PHP_VERSION === $argv[1] ? 0 : 1);' "$1"
''', 'check', version)
subprocess.run(['docker', 'run', '--rm', '--user', '65534:65534', '--entrypoint', '/bin/sh',
                image, '-ec', 'for f in /opt/bitnami/php/licenses/* /opt/bitnami/php/.spdx-php.json; do test -r "$f"; done'],
               check=True)
print('PASS: licenses readable, SUID/SGID absent, real PHP version and SPDX checked; scanner absent')
