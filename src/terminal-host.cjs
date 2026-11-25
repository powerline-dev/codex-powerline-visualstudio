const readline = require('node:readline');
const { spawn } = require('node-pty');

let terminal;
let generation = 0;
let pending = '';
let inFlight = false;
let paused = false;
let stopping = false;
const HIGH_WATER = 1024 * 1024;

function send(message) {
    process.stdout.write(JSON.stringify(message) + '\n');
}

function flush() {
    if (inFlight || !pending || stopping) return;
    inFlight = true;
    const text = pending.slice(0, 32768);
    pending = pending.slice(text.length);
    send({ type: 'output', text, generation });
}

function write(text) {
    pending += text;
    if (terminal && pending.length >= HIGH_WATER && !paused) {
        terminal.pause();
        paused = true;
    }
    flush();
}

function stopTerminal() {
    const child = terminal;
    terminal = undefined;
    paused = false;
    if (child) {
        child.resume();
        child.kill();
    }
}

function start(message) {
    if (typeof message.cwd !== 'string' || !validSize(message)) return;
    stopTerminal();
    generation++;
    pending = '';
    inFlight = false;
    send({ type: 'reset', generation });
    try {
        if (process.platform !== 'win32' || process.arch !== 'x64') {
            throw new Error('This release needs Windows x64 and an x64 Node.js installation.');
        }
        const child = spawn(process.env.ComSpec || `${process.env.SystemRoot}\\System32\\cmd.exe`,
            ['/d', '/c', 'codex-powerline', 'run'], {
                cols: message.cols, rows: message.rows, cwd: message.cwd, useConptyDll: true,
                env: { ...process.env, NoDefaultCurrentDirectoryInExePath: '1',
                    TERM: 'xterm-256color', COLORTERM: 'truecolor' }, name: 'xterm-256color'
            });
        terminal = child;
        send({ type: 'started', pid: child.pid });
        child.onData(text => { if (terminal === child) write(text); });
        child.onExit(({ exitCode }) => {
            if (terminal !== child) return;
            terminal = undefined;
            paused = false;
            write(`\r\nCodex Powerline exited with code ${exitCode}. Use Restart Terminal to run it again.\r\n`);
            send({ type: 'exited', exitCode });
        });
    } catch (error) {
        write(`Could not start codex-powerline run.\r\n${error.message}\r\nCheck that both CLIs are installed and on PATH, then use Restart Terminal.\r\n`);
        send({ type: 'exited', exitCode: 1 });
    }
}

function validSize(message) {
    return [message.cols, message.rows].every(value => Number.isInteger(value) && value > 0 && value <= 1000);
}

function shutdown() {
    if (stopping) return;
    stopping = true;
    stopTerminal();
    // node-pty gathers the Windows console process tree asynchronously before killing it.
    setTimeout(() => process.exit(0), 6000).unref();
}

const input = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
input.on('line', line => {
    let message;
    // .NET Framework can write a UTF-8 BOM when it opens redirected stdin.
    try { message = JSON.parse(line.replace(/^\uFEFF/, '')); } catch { return; }
    if (!message || typeof message !== 'object' || stopping) return;
    try {
        if (message.type === 'start') start(message);
        else if (message.type === 'resize' && validSize(message)) terminal?.resize(message.cols, message.rows);
        else if (message.type === 'input' && typeof message.text === 'string' && message.text.length <= 65536) terminal?.write(message.text);
        else if (message.type === 'ack' && message.generation === generation) {
            inFlight = false;
            flush();
            if (terminal && paused && pending.length < HIGH_WATER) {
                paused = false;
                terminal.resume();
            }
        } else if (message.type === 'stop') shutdown();
    } catch (error) { write(`\r\nTerminal error: ${error.message}\r\n`); }
});
input.on('close', shutdown);
process.on('SIGTERM', shutdown);
process.stdout.on('error', shutdown);
send({ type: 'ready' });
