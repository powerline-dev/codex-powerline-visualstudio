const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { mkdtempSync, writeFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const path = require('node:path');
const readline = require('node:readline');
const { once } = require('node:events');

const windows = process.platform === 'win32' && process.arch === 'x64';

function alive(pid) {
    try { process.kill(pid, 0); return true; } catch { return false; }
}

async function waitUntil(predicate, label, timeout = 12000) {
    const end = Date.now() + timeout;
    while (Date.now() < end) {
        if (predicate()) return;
        await new Promise(resolve => setTimeout(resolve, 40));
    }
    throw new Error(`Timed out: ${label}`);
}

function harness(t, mock = true) {
    const directory = mkdtempSync(path.join(tmpdir(), 'powerline-vs-test-'));
    if (mock) {
        writeFileSync(path.join(directory, 'codex-powerline.cmd'), `@"${process.execPath}" "%~dp0mock-cli.cjs"\r\n`);
        writeFileSync(path.join(directory, 'mock-cli.cjs'), `
            const readline = require('node:readline');
            console.log('MOCK_READY:' + process.pid + ':' + process.cwd());
            const input = readline.createInterface({ input: process.stdin });
            input.on('line', line => {
                if (line === 'size') {
                    process.stdout._refreshSize();
                    console.log('SIZE:' + process.stdout.columns + 'x' + process.stdout.rows);
                }
                else if (line === 'flood') process.stdout.write('X'.repeat(2 * 1024 * 1024) + 'FLOOD_DONE');
                else if (line === 'exit') process.exit(0);
                else console.log('ECHO:' + line);
            });
        `);
    }
    const child = spawn(process.execPath, [path.resolve('runtime/terminal-host.cjs')], {
        env: { ...process.env, PATH: `${mock ? directory + ';' : ''}${process.env.SystemRoot}\\System32`,
            NoDefaultCurrentDirectoryInExePath: '1' }, stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true
    });
    const state = { child, directory, messages: [], output: '', autoAck: true, errors: '' };
    state.send = message => child.stdin.write(JSON.stringify(message) + '\n');
    state.start = (cols = 90, rows = 28) => state.send({ type: 'start', cwd: directory, cols, rows });
    child.stderr.on('data', data => state.errors += data.toString());
    readline.createInterface({ input: child.stdout }).on('line', line => {
        const message = JSON.parse(line);
        state.messages.push(message);
        if (message.type === 'output') {
            state.output += message.text;
            if (state.autoAck) state.send({ type: 'ack', generation: message.generation });
        }
    });
    t.after(async () => {
        if (child.exitCode === null) {
            child.stdin.end();
            await Promise.race([once(child, 'exit'), new Promise((_, reject) => setTimeout(() => {
                child.kill(); reject(new Error('Terminal host did not shut down.'));
            }, 10000).unref())]);
        }
        assert.equal(path.dirname(path.resolve(directory)), path.resolve(tmpdir()));
        assert.ok(path.basename(directory).startsWith('powerline-vs-test-'));
        rmSync(directory, { recursive: true, force: true });
        assert.equal(state.errors, '');
    });
    return state;
}

test('native PTY preserves cwd, Unicode input, resize, restart, and EOF cleanup', { skip: !windows }, async t => {
    const host = harness(t);
    host.child.stdin.write('\uFEFF');
    host.start();
    await waitUntil(() => host.output.includes('MOCK_READY:'), 'CLI start');
    assert.ok(host.output.includes(host.directory));
    const firstPid = Number(host.output.match(/MOCK_READY:(\d+):/)[1]);
    host.send({ type: 'input', text: 'hello \u017elut\u00fd\r' });
    await waitUntil(() => host.output.includes('ECHO:hello \u017elut\u00fd'), 'Unicode keyboard input');
    host.send({ type: 'resize', cols: 120, rows: 35 });
    host.send({ type: 'input', text: 'size\r' });
    await waitUntil(() => host.output.includes('SIZE:120x35'), 'native PTY resize');
    host.start(100, 30);
    await waitUntil(() => (host.output.match(/MOCK_READY:/g) || []).length === 2, 'restart');
    await waitUntil(() => !alive(firstPid), 'old CLI cleanup');
    const secondPid = Number([...host.output.matchAll(/MOCK_READY:(\d+):/g)][1][1]);
    assert.notEqual(firstPid, secondPid);
    host.child.stdin.end();
    await once(host.child, 'exit');
    await waitUntil(() => !alive(secondPid), 'CLI cleanup after host EOF');
});

test('output waits for rendering acknowledgement and resumes after backpressure', { skip: !windows }, async t => {
    const host = harness(t);
    host.start();
    await waitUntil(() => host.output.includes('MOCK_READY:'), 'CLI start');
    host.autoAck = false;
    host.send({ type: 'input', text: 'flood\r' });
    const prior = host.messages.filter(message => message.type === 'output').length;
    await waitUntil(() => host.messages.filter(message => message.type === 'output').length > prior, 'first output chunk');
    const count = host.messages.filter(message => message.type === 'output').length;
    await new Promise(resolve => setTimeout(resolve, 200));
    assert.equal(host.messages.filter(message => message.type === 'output').length, count);
    host.autoAck = true;
    const latest = host.messages.filter(message => message.type === 'output').at(-1);
    host.send({ type: 'ack', generation: latest.generation });
    await waitUntil(() => host.output.includes('FLOOD_DONE'), 'output resume');
});

test('missing CLI and malformed messages do not crash the host', { skip: !windows }, async t => {
    const host = harness(t, false);
    host.child.stdin.write('not-json\nnull\n');
    host.send({ type: 'start', cwd: host.directory, cols: -1, rows: 28 });
    host.start();
    await waitUntil(() => host.messages.some(message => message.type === 'exited'), 'missing CLI exit');
    await waitUntil(() => host.output.includes('Use Restart Terminal'), 'exit guidance');
    assert.ok(host.output.includes('codex-powerline'));
    assert.equal(host.child.exitCode, null);
});
