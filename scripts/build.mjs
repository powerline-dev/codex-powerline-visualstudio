import { build } from 'esbuild';
import { cpSync, mkdirSync, readdirSync } from 'node:fs';

mkdirSync('web/dist', { recursive: true });
mkdirSync('runtime/node_modules/node-pty', { recursive: true });
await build({ entryPoints: ['web/terminal.ts'], bundle: true, platform: 'browser', target: 'chrome120',
    outfile: 'web/dist/terminal.js', loader: { '.woff2': 'file' }, assetNames: 'powerline-symbols' });
await build({ entryPoints: ['src/terminal-host.cjs'], bundle: true, platform: 'node', target: 'node22',
    outfile: 'runtime/terminal-host.cjs', external: ['node-pty'] });
cpSync('web/index.html', 'web/dist/index.html');
for (const item of ['package.json', 'LICENSE', 'lib', 'prebuilds/win32-x64']) {
    cpSync(`node_modules/node-pty/${item}`, `runtime/node_modules/node-pty/${item}`, {
        recursive: true, filter: source => !/\.(map|pdb|ts)$/.test(source)
    });
}
const conptyVersion = readdirSync('node_modules/node-pty/third_party/conpty')[0];
cpSync(`node_modules/node-pty/third_party/conpty/${conptyVersion}/win10-x64`,
    'runtime/node_modules/node-pty/build/Release/conpty', { recursive: true });
