import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';

const here = path.dirname(fileURLToPath(import.meta.url));
const serverRoot = path.resolve(here, '../../godot-mcp-pro/server');
const sdk = path.join(serverRoot, 'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const { Client } = await import(pathToFileURL(path.join(sdk, 'index.js')));
const { StdioClientTransport } = await import(pathToFileURL(path.join(sdk, 'stdio.js')));
const projectPath = path.resolve(here, '../game');
const outputDir = path.resolve(here, '../artifacts/mcp');
await fs.mkdir(outputDir, {recursive: true});
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [path.join(serverRoot, 'build/index.js')],
  env: {...process.env, GODOT_PROJECT_PATH: projectPath},
  stderr: 'inherit',
});
const client = new Client({name:'ghost-inside-local-verifier',version:'1.0.0'});
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
let imageIndex = 0;
async function saveResult(result, label) {
  const clean = structuredClone(result);
  for (const block of clean.content ?? []) {
    if (block.type === 'image' && block.data) {
      const filename = path.join(outputDir, `${Date.now()}-${label}-${imageIndex++}.png`);
      await fs.writeFile(filename, Buffer.from(block.data, 'base64'));
      delete block.data;
      block.path = filename;
    }
  }
  console.log(JSON.stringify(clean, null, 2));
}
try {
  await client.connect(transport);
  const mode = process.argv[2] ?? 'list';
  if (mode === 'list') {
    const result = await client.listTools();
    await fs.writeFile(path.join(outputDir, 'tools.json'), JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result.tools.map(tool => ({name:tool.name,inputSchema:tool.inputSchema})), null, 2));
  } else {
    await sleep(Number(process.env.GODOT_MCP_CONNECT_WAIT_MS ?? 5000));
    const steps = mode === 'sequence'
      ? JSON.parse(await fs.readFile(process.argv[3], 'utf8'))
      : [{name:mode, arguments:JSON.parse(process.argv[3] ?? '{}')}];
    for (const step of steps) {
      if (step.wait_ms) { await sleep(step.wait_ms); continue; }
      const result = await client.callTool({name:step.name, arguments:step.arguments ?? {}}, undefined, {timeout:60000});
      await saveResult(result, step.name);
      if (result.isError && !step.continue_on_error) { process.exitCode = 1; break; }
    }
  }
} finally {
  await client.close();
}
