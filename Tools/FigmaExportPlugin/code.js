// Runs inside Figma's plugin sandbox. All files are saved by the local UI.
const MAX_NODES = 3000;
const MAX_IMAGE_COUNT = 100;
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;
const MAX_PREVIEW_BYTES = 8 * 1024 * 1024;
const MAX_JSON_CHARS = 16 * 1024 * 1024;

figma.showUI(__html__, { width: 420, height: 620, themeColors: true });

let exporting = false;
let layoutPlan = null;

figma.ui.onmessage = async (message) => {
  if (!message || exporting) return;
  if (message.type === 'layout-export') {
    try {
      await figma.currentPage.loadAsync();
      const entries = collectLayout(figma.currentPage);
      const json = JSON.stringify({
        schema: 'festicore-page-layout-v1',
        source: { fileKey: figma.fileKey || null, pageId: figma.currentPage.id, pageName: figma.currentPage.name },
        entries
      }, null, 2);
      if (json.length > MAX_JSON_CHARS) throw new Error('페이지 위치 JSON이 1,600만 자를 초과합니다.');
      figma.ui.postMessage({ type: 'layout-ready', json, count: entries.length, pageName: figma.currentPage.name });
    } catch (error) { postError(error); }
    return;
  }
  if (message.type === 'layout-preview') {
    layoutPlan = null;
    try {
      await figma.currentPage.loadAsync();
      const source = JSON.parse(message.json);
      const report = planLayout(source, figma.currentPage);
      if (report.issues.length === 0) layoutPlan = { source, items: report.plan };
      figma.ui.postMessage({ type: 'layout-report', count: report.plan.length, issues: report.issues });
    } catch (error) { postError(error); }
    return;
  }
  if (message.type === 'layout-apply') {
    if (!layoutPlan) return postError(new Error('먼저 위치 대조를 실행하고 모든 문제를 해결하세요.'));
    try {
      await figma.currentPage.loadAsync();
      // Recheck the tree immediately before writing; a stale preview must not edit a changed page.
      const report = planLayout(layoutPlan.source, figma.currentPage);
      if (report.issues.length || report.plan.length !== layoutPlan.items.length ||
          report.plan.some((item, i) => item.node !== layoutPlan.items[i].node ||
            item.currentX !== layoutPlan.items[i].currentX || item.currentY !== layoutPlan.items[i].currentY)) {
        layoutPlan = null;
        throw new Error('미리보기 이후 레이어가 변경되었습니다. 위치 대조를 다시 실행하세요.');
      }
      const items = layoutPlan.items;
      layoutPlan = null;
      for (const item of items) {
        item.node.x = item.x;
        item.node.y = item.y;
      }
      figma.ui.postMessage({ type: 'layout-applied', count: items.length });
    } catch (error) { postError(error); }
    return;
  }
  if (message.type !== 'export') return;
  exporting = true;
  figma.ui.postMessage({ type: 'progress', text: '선택한 프레임 또는 섹션을 읽는 중…' });

  try {
    const selection = figma.currentPage.selection;
    if (selection.length !== 1 || !['FRAME', 'SECTION'].includes(selection[0].type)) {
      throw new Error('프레임 또는 섹션 하나만 선택한 뒤 다시 실행하세요.');
    }

    const frame = selection[0];
    const references = collectImageReferences(frame);
    const uniqueHashes = [...new Set(references.map((reference) => reference.imageHash))];
    if (uniqueHashes.length > MAX_IMAGE_COUNT) {
      throw new Error(`이미지 채우기가 ${MAX_IMAGE_COUNT}개를 초과합니다. 더 작은 프레임을 선택하세요.`);
    }

    figma.ui.postMessage({ type: 'progress', text: '레이어 JSON과 미리보기 PNG를 만드는 중…' });
    const rest = await frame.exportAsync({ format: 'JSON_REST_V1' });
    const preview = await frame.exportAsync({
      format: 'PNG',
      constraint: { type: 'WIDTH', value: Math.min(Math.max(Math.ceil(frame.width), 1), 1440) }
    });
    if (preview.length > MAX_PREVIEW_BYTES) {
      throw new Error('미리보기 PNG가 8 MB를 초과합니다. 더 작은 프레임을 선택하세요.');
    }

    figma.ui.postMessage({ type: 'progress', text: `이미지 채우기 ${uniqueHashes.length}개를 읽는 중…` });
    const images = {};
    let imageBytes = 0;
    for (const hash of uniqueHashes) {
      const image = figma.getImageByHash(hash);
      if (!image) throw new Error(`이미지 채우기를 찾을 수 없습니다: ${hash}`);
      const bytes = await image.getBytesAsync();
      imageBytes += bytes.length;
      if (imageBytes > MAX_IMAGE_BYTES) {
        throw new Error('이미지 원본 합계가 20 MB를 초과합니다. 더 작은 프레임을 선택하세요.');
      }
      images[hash] = {
        mimeType: imageMimeType(bytes),
        byteLength: bytes.length,
        base64: figma.base64Encode(bytes)
      };
    }

    const bundle = {
      schema: 'festicore-figma-export-v1',
      exportedAt: new Date().toISOString(),
      source: {
        fileKey: figma.fileKey || null,
        pageId: figma.currentPage.id,
        pageName: figma.currentPage.name,
        nodeId: frame.id,
        nodeName: frame.name
      },
      figmaRest: rest,
      imageFills: {
        references,
        byHash: images
      }
    };
    const json = JSON.stringify(bundle, null, 2);
    if (json.length > MAX_JSON_CHARS) {
      throw new Error('결과 JSON이 1,600만 자를 초과합니다. 더 작은 프레임을 선택하세요.');
    }

    figma.ui.postMessage({
      type: 'ready',
      name: frame.name,
      nodeId: frame.id,
      nodeCount: countNodes(frame),
      imageCount: uniqueHashes.length,
      json,
      previewBase64: figma.base64Encode(preview)
    });
  } catch (error) {
    postError(error);
  } finally {
    exporting = false;
  }
};

function postError(error) {
  figma.ui.postMessage({ type: 'error', text: error instanceof Error ? error.message : String(error) });
}

function collectLayout(page) {
  const entries = [];
  function visit(node, path) {
    const nextPath = path.concat([{ type: node.type, name: node.name }]);
    if (node.type === 'FRAME' || node.type === 'SECTION') {
      if (entries.length >= MAX_NODES) throw new Error(`페이지 프레임·섹션이 ${MAX_NODES}개를 초과합니다.`);
      entries.push({ path: nextPath, x: node.x, y: node.y });
    }
    if ('children' in node && node.type !== 'INSTANCE') node.children.forEach((child) => visit(child, nextPath));
  }
  page.children.forEach((child) => visit(child, []));
  return entries;
}

function pathKey(path) { return JSON.stringify(path); }

function planLayout(source, page) {
  if (!source || source.schema !== 'festicore-page-layout-v1' || !Array.isArray(source.entries) || !source.source) {
    throw new Error('지원하지 않는 페이지 위치 JSON입니다.');
  }
  if (typeof source.source.pageName !== 'string' || source.source.pageName !== page.name) {
    throw new Error('원본과 복제본의 페이지 이름이 다릅니다. 같은 페이지를 열고 다시 대조하세요.');
  }
  if ((source.source.fileKey && source.source.fileKey === figma.fileKey) ||
      (!source.source.fileKey && !figma.fileKey && source.source.pageId === page.id)) {
    throw new Error('원본 페이지에는 위치를 적용할 수 없습니다. 편집 가능한 복제본을 여세요.');
  }
  if (source.entries.length > MAX_NODES) throw new Error('위치 항목이 허용 범위를 초과합니다.');
  const targets = new Map();
  let frameCount = 0;
  function visit(node, path) {
    const nextPath = path.concat([{ type: node.type, name: node.name }]);
    if (node.type === 'FRAME' || node.type === 'SECTION') {
      const key = pathKey(nextPath);
      if (++frameCount > MAX_NODES) throw new Error(`대상 프레임·섹션이 ${MAX_NODES}개를 초과합니다.`);
      targets.set(key, (targets.get(key) || []).concat(node));
    }
    if ('children' in node && node.type !== 'INSTANCE') node.children.forEach((child) => visit(child, nextPath));
  }
  page.children.forEach((child) => visit(child, []));
  const sourceCounts = new Map();
  for (const entry of source.entries) {
    if (!Array.isArray(entry.path) || !entry.path.length ||
        entry.path.some((part) => !part || typeof part.type !== 'string' || typeof part.name !== 'string') ||
        !['FRAME', 'SECTION'].includes(entry.path[entry.path.length - 1].type) ||
        !Number.isFinite(entry.x) || !Number.isFinite(entry.y)) {
      throw new Error('위치 JSON의 경로 또는 좌표가 잘못되었습니다.');
    }
    const key = pathKey(entry.path);
    sourceCounts.set(key, (sourceCounts.get(key) || 0) + 1);
  }
  const issues = [];
  const plan = [];
  for (const entry of source.entries) {
    const key = pathKey(entry.path);
    const label = entry.path.map((part) => `${part.type}:${part.name}`).join(' / ');
    const matches = targets.get(key) || [];
    if (sourceCounts.get(key) > 1 || matches.length > 1) issues.push(`중복 경로: ${label}`);
    else if (!matches.length) issues.push(`대상 없음: ${label}`);
    else if (matches[0].parent && 'layoutMode' in matches[0].parent &&
             matches[0].parent.layoutMode !== 'NONE' && matches[0].layoutPositioning !== 'ABSOLUTE') {
      issues.push(`자동 배치 위치 변경 불가: ${label}`);
    } else plan.push({ node: matches[0], x: entry.x, y: entry.y, currentX: matches[0].x, currentY: matches[0].y });
  }
  // Do not silently leave clone-only frames at unrelated positions.
  const sourceKeys = new Set(sourceCounts.keys());
  for (const [key, matches] of targets) {
    if (!sourceKeys.has(key)) issues.push(`원본 없음: ${matches[0].name}`);
  }
  return { plan, issues: [...new Set(issues)] };
}

function collectImageReferences(root) {
  const references = [];
  let count = 0;

  function visit(node) {
    count += 1;
    if (count > MAX_NODES) {
      throw new Error(`레이어가 ${MAX_NODES}개를 초과합니다. 더 작은 프레임을 선택하세요.`);
    }

    for (const property of ['fills', 'strokes', 'backgrounds']) {
      if (!(property in node)) continue;
      const paints = node[property];
      if (!Array.isArray(paints)) continue;
      paints.forEach((paint, index) => {
        if (paint.type === 'IMAGE' && paint.imageHash) {
          references.push({
            nodeId: node.id,
            property,
            index,
            imageHash: paint.imageHash
          });
        }
      });
    }

    if ('children' in node) node.children.forEach(visit);
  }

  visit(root);
  return references;
}

function countNodes(root) {
  let count = 1;
  if ('children' in root) {
    for (const child of root.children) count += countNodes(child);
  }
  return count;
}

function imageMimeType(bytes) {
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) return 'image/png';
  if (bytes[0] === 0xff && bytes[1] === 0xd8) return 'image/jpeg';
  if (bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) return 'image/gif';
  if (bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46) return 'image/webp';
  return 'application/octet-stream';
}
