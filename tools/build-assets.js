'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const target = path.join(root, 'web', 'assets', 'js');

const assets = [
    ['node_modules/alpinejs/dist/cdn.min.js', 'alpine.min.js'],
    ['node_modules/flowbite/dist/flowbite.min.js', 'flowbite.min.js'],
    ['node_modules/lucide/dist/umd/lucide.min.js', 'lucide.min.js'],
];

fs.mkdirSync(target, { recursive: true });

for (const [source, name] of assets) {
    const from = path.join(root, source);
    const to = path.join(target, name);

    if (!fs.existsSync(from)) {
        throw new Error(`No se encontró ${source}; ejecutá npm install primero.`);
    }

    fs.copyFileSync(from, to);
    console.log(`js: ${name}`);
}
