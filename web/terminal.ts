import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { Unicode11Addon } from '@xterm/addon-unicode11';
import '@xterm/xterm/css/xterm.css';
import './terminal.css';

declare global {
    interface Window {
        chrome: { webview: {
            postMessage(message: unknown): void;
            addEventListener(type: 'message', listener: (event: MessageEvent) => void): void;
        } };
    }
}

const bridge = window.chrome.webview;
const container = document.querySelector<HTMLDivElement>('#terminal')!;
const terminal = new Terminal({ allowProposedApi: true, fontFamily: '"Codex Powerline Symbols", Consolas, monospace',
    fontSize: 14, theme: { background: '#1e1e1e', foreground: '#d4d4d4' }, scrollback: 5000 });
const fit = new FitAddon();
terminal.loadAddon(fit);
terminal.loadAddon(new Unicode11Addon());
terminal.unicode.activeVersion = '11';
terminal.open(container);
let cols = 0;
let rows = 0;
function resize(): void {
    if (!container.clientWidth || !container.clientHeight) return;
    fit.fit();
    if (terminal.cols === cols && terminal.rows === rows) return;
    cols = terminal.cols;
    rows = terminal.rows;
    bridge.postMessage({ type: 'resize', cols, rows });
}
bridge.addEventListener('message', ({ data }) => {
    if (data?.type === 'output' && typeof data.text === 'string') {
        terminal.write(data.text, () => bridge.postMessage({ type: 'ack', generation: data.generation }));
    } else if (data?.type === 'reset') {
        terminal.reset();
        terminal.focus();
    } else if (data?.type === 'theme' && typeof data.background === 'string' && typeof data.foreground === 'string') {
        terminal.options.theme = { background: data.background, foreground: data.foreground, cursor: data.foreground };
        document.body.style.setProperty('--terminal-background', data.background);
    } else if (data?.type === 'focus') terminal.focus();
});
terminal.onData(text => {
    // Keep large clipboard pastes inside the host's per-message limit.
    for (let start = 0; start < text.length;) {
        let end = Math.min(start + 16384, text.length);
        if (end < text.length && /[\uD800-\uDBFF]/.test(text[end - 1])) end--;
        bridge.postMessage({ type: 'input', text: text.slice(start, end) });
        start = end;
    }
});
terminal.onBinary(text => bridge.postMessage({ type: 'input', text }));
void document.fonts.load('12px "Codex Powerline Symbols"', '\uE0B0\uE0B6').then(() => {
    new ResizeObserver(resize).observe(container);
    resize();
    terminal.focus();
});
