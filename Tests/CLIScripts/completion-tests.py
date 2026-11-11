#!/usr/bin/env python3
"""Exercise generated zsh completion in a real line editor, using local fixtures.

No helper, Keychain, real home, installed app, or secret value is used.
"""

import base64
import json
import os
from pathlib import Path
import pty
import re
import select
import shlex
import signal
import subprocess
import sys
import tempfile
import time


class Shell:
    def __init__(self, env, completion):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execve('/bin/zsh', ['zsh', '-f'], env)
        self.pending = b''
        setup = (
            'PROMPT="KEY-TEST> "; RPROMPT=""; '
            'autoload -Uz compinit; compinit -D; '
            f'source {shlex.quote(str(completion))}; '
            '_capture_buffer() { local snapshot="$BUFFER"; BUFFER=""; '
            'print; print -r -- "__BUFFER__$(print -rn -- "$snapshot" | /usr/bin/base64)"; '
            'zle reset-prompt; }; zle -N _capture_buffer; '
            'bindkey -e; bindkey "^X" _capture_buffer; '
            'print __SHELL_READY__;'
        )
        os.write(self.fd, (setup + '\n').encode())
        self.read_until(rb'\r\n__SHELL_READY__\r\n')

    def read_until(self, pattern):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            match = re.search(pattern, self.pending)
            if match:
                self.pending = self.pending[match.end():]
                return match
            if select.select([self.fd], [], [], 0.1)[0]:
                self.pending += os.read(self.fd, 65536)
        raise AssertionError('zsh completion timed out: ' + repr(self.pending[-2000:]))

    def complete(self, text):
        os.write(self.fd, text.encode() + b'\t')
        # Wait for the editor to process Tab before requesting its buffer.
        time.sleep(0.25)
        os.write(self.fd, b'\x18')
        match = self.read_until(rb'__BUFFER__([A-Za-z0-9+/=]+)\r\n')
        return base64.b64decode(match.group(1)).decode()

    def close(self):
        os.kill(self.pid, signal.SIGKILL)
        os.waitpid(self.pid, 0)
        os.close(self.fd)


def main():
    cli = Path(sys.argv[1]).resolve()
    fixture = Path(__file__).resolve().parents[1] / 'ScriptFixtures/completion-manifest.json'
    manifest = json.loads(fixture.read_bytes())
    vault_id = manifest['content']['manifest']['vaultID']
    with tempfile.TemporaryDirectory(prefix='key-completion-tests-') as tmp:
        home = Path(tmp)
        env = dict(os.environ, HOME=tmp, CFFIXED_USER_HOME=tmp, TERM='xterm-256color')
        generated = subprocess.run([str(cli), '--generate-completion-script', 'zsh'],
                                   env=env, capture_output=True, check=True, timeout=10)
        assert not generated.stderr
        command = generated.stdout.splitlines()[0].decode().removeprefix('#compdef ')
        assert command in ('key', 'key-preview')
        support = home / 'Library/Application Support' / ('Key' if command == 'key' else 'Key Preview')
        cache = support / 'v3-checkpoint-manifests'
        cache.mkdir(parents=True)
        (cache / (vault_id + '.json')).write_bytes(fixture.read_bytes())
        # Deliberately absent: suggestions must not open the provider folder.
        (support / 'config.toml').write_text(
            f'vault_dir = "{home}/offline-vault"\nvault_id = "{vault_id}"\n'
        )
        bindir = home / 'bin'
        bindir.mkdir()
        (bindir / command).symlink_to(cli)
        env['PATH'] = str(bindir) + ':' + env.get('PATH', '/usr/bin:/bin')
        completion = home / ('_' + command)
        completion.write_bytes(generated.stdout)
        if command == 'key':
            tracked = Path(__file__).resolve().parents[2] / 'completions/_key'
            assert generated.stdout == tracked.read_bytes(), 'Regenerate the shipped zsh completion'
        shell = Shell(env, completion)
        try:
            checks = {
                f'{command} ge': [command, 'get'],
                f'{command} reco': [command, 'recovery'],
                f'{command} get --totp-s': [command, 'get', '--totp-secret'],
                f'{command} get work/a': [command, 'get', 'work/a b'],
                f'{command} copy work/col': [command, 'copy', 'work/colon:name'],
                f'{command} edit work/quo': [command, 'edit', "work/quote'$(echo nope)"],
                f'{command} remove 個': [command, 'remove', '個人/メール'],
                f'{command} duplicate work/a\\ b work/col': [command, 'duplicate', 'work/a b', 'work/colon:name'],
                f'{command} rename work/a\\ b work/col': [command, 'rename', 'work/a b', 'work/colon:name'],
            }
            for text, expected in checks.items():
                actual = shell.complete(text)
                assert shlex.split(actual) == expected, (text, actual, expected)
            for operation in ('get', 'add'):
                actual = shell.complete(f'{command} {operation} wo')
                assert actual == f'{command} {operation} work/', repr(actual)
            empty = home / 'empty-directory'
            empty.mkdir()
            actual = shell.complete(f'{command} init {home}/empty-d')
            assert shlex.split(actual) == [command, 'init', str(empty) + '/'], repr(actual)
        finally:
            shell.close()
        assert not (home / 'offline-vault').exists()
        print('Generated zsh: commands, flags, hierarchy, both transfer arguments, quoting, Unicode, and filesystem Tab completion passed.')


if __name__ == '__main__':
    main()
