const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function fixture() {
  const messages = [];
  const figma = {
    fileKey: 'clone',
    showUI() {},
    ui: { postMessage(message) { messages.push(message); }, onmessage: null }
  };
  const context = vm.createContext({ figma, __html__: '', Date, JSON, Set, Map, Error });
  vm.runInContext(fs.readFileSync(path.join(__dirname, 'code.js'), 'utf8'), context);
  return { figma, messages, context };
}

function node(type, name, x, y, children = [], extra = {}) {
  const result = { type, name, x, y, children, ...extra };
  for (const child of children) child.parent = result;
  return result;
}

function page(children) {
  const result = node('PAGE', 'Widget', 0, 0, children);
  result.id = 'page-id';
  result.loadAsync = async () => {};
  return result;
}

test('exports hierarchy and applies original local positions after preview', async () => {
  const { figma, messages } = fixture();
  const original = page([node('SECTION', 'S00', 100, 200, [node('FRAME', 'Home', 12, 34)])]);
  figma.fileKey = 'original';
  figma.currentPage = original;
  await figma.ui.onmessage({ type: 'layout-export' });
  const exported = JSON.parse(messages.at(-1).json);
  assert.equal(exported.entries.length, 2);
  assert.deepEqual(Array.from(exported.entries[1].path, (part) => part.name), ['S00', 'Home']);

  const clone = page([node('SECTION', 'S00', 900, 800, [node('FRAME', 'Home', 3, 4)])]);
  figma.fileKey = 'clone';
  figma.currentPage = clone;
  await figma.ui.onmessage({ type: 'layout-preview', json: JSON.stringify(exported) });
  assert.equal(messages.at(-1).type, 'layout-report');
  assert.equal(messages.at(-1).issues.length, 0);
  assert.equal(clone.children[0].x, 900);
  await figma.ui.onmessage({ type: 'layout-apply' });
  assert.equal(messages.at(-1).type, 'layout-applied');
  assert.equal(clone.children[0].x, 100);
  assert.equal(clone.children[0].children[0].y, 34);
});

test('missing, duplicate, and auto-layout paths prevent every write', async () => {
  const { figma, messages } = fixture();
  const source = {
    schema: 'festicore-page-layout-v1', source: { pageName: 'Widget' },
    entries: [
      { path: [{ type: 'FRAME', name: 'A' }], x: 1, y: 2 },
      { path: [{ type: 'FRAME', name: 'Missing' }], x: 3, y: 4 }
    ]
  };
  const clone = page([node('FRAME', 'A', 50, 60), node('FRAME', 'A', 70, 80)]);
  figma.currentPage = clone;
  await figma.ui.onmessage({ type: 'layout-preview', json: JSON.stringify(source) });
  assert.match(messages.at(-1).issues.join('\n'), /중복 경로/);
  assert.match(messages.at(-1).issues.join('\n'), /대상 없음/);
  await figma.ui.onmessage({ type: 'layout-apply' });
  assert.equal(messages.at(-1).type, 'error');
  assert.equal(clone.children[0].x, 50);

  const auto = page([node('FRAME', 'Parent', 0, 0, [node('FRAME', 'Child', 7, 8)], { layoutMode: 'VERTICAL' })]);
  figma.currentPage = auto;
  const autoSource = { schema: source.schema, source: source.source, entries: [
    { path: [{ type: 'FRAME', name: 'Parent' }], x: 0, y: 0 },
    { path: [{ type: 'FRAME', name: 'Parent' }, { type: 'FRAME', name: 'Child' }], x: 2, y: 3 }
  ] };
  await figma.ui.onmessage({ type: 'layout-preview', json: JSON.stringify(autoSource) });
  assert.match(messages.at(-1).issues.join('\n'), /자동 배치/);
});

test('stale preview cannot apply to a changed hierarchy', async () => {
  const { figma, messages } = fixture();
  const clone = page([node('FRAME', 'A', 20, 30)]);
  figma.currentPage = clone;
  const source = { schema: 'festicore-page-layout-v1', source: { pageName: 'Widget' }, entries: [
    { path: [{ type: 'FRAME', name: 'A' }], x: 1, y: 2 }
  ] };
  await figma.ui.onmessage({ type: 'layout-preview', json: JSON.stringify(source) });
  clone.children[0].name = 'Changed';
  await figma.ui.onmessage({ type: 'layout-apply' });
  assert.equal(messages.at(-1).type, 'error');
  assert.equal(clone.children[0].x, 20);
});

test('large pages count only frames and sections', async () => {
  const { figma, messages } = fixture();
  const decorations = Array.from({ length: 3100 }, (_, i) => node('RECTANGLE', `Decoration ${i}`, 0, 0));
  figma.currentPage = page([node('FRAME', 'S00', 10, 20, decorations)]);
  await figma.ui.onmessage({ type: 'layout-export' });
  assert.equal(messages.at(-1).type, 'layout-ready');
  assert.equal(messages.at(-1).count, 1);
});

test('wrong page and original file are rejected before preview', async () => {
  const { figma, messages } = fixture();
  figma.currentPage = page([node('FRAME', 'S00', 10, 20)]);
  const source = { schema: 'festicore-page-layout-v1', source: { pageName: 'Other', fileKey: 'original' }, entries: [] };
  await figma.ui.onmessage({ type: 'layout-preview', json: JSON.stringify(source) });
  assert.match(messages.at(-1).text, /페이지 이름/);
  source.source.pageName = 'Widget';
  figma.fileKey = 'original';
  await figma.ui.onmessage({ type: 'layout-preview', json: JSON.stringify(source) });
  assert.match(messages.at(-1).text, /원본 페이지/);
});

test('position changes after preview require another comparison', async () => {
  const { figma, messages } = fixture();
  const clone = page([node('FRAME', 'S00', 20, 30)]);
  figma.currentPage = clone;
  const source = { schema: 'festicore-page-layout-v1', source: { pageName: 'Widget' }, entries: [
    { path: [{ type: 'FRAME', name: 'S00' }], x: 1, y: 2 }
  ] };
  await figma.ui.onmessage({ type: 'layout-preview', json: JSON.stringify(source) });
  clone.children[0].x = 40;
  await figma.ui.onmessage({ type: 'layout-apply' });
  assert.equal(messages.at(-1).type, 'error');
  assert.equal(clone.children[0].x, 40);
});
