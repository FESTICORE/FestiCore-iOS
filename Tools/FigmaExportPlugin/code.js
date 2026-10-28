// Runs inside Figma's plugin sandbox. All files are saved by the local UI.
const MAX_NODES = 3000;
const MAX_IMAGE_COUNT = 100;
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;
const MAX_PREVIEW_BYTES = 8 * 1024 * 1024;
const MAX_JSON_CHARS = 16 * 1024 * 1024;

figma.showUI(__html__, { width: 380, height: 440, themeColors: true });

let exporting = false;

figma.ui.onmessage = async (message) => {
  if (!message || message.type !== 'export' || exporting) return;
  exporting = true;
  figma.ui.postMessage({ type: 'progress', text: '선택 프레임을 읽는 중…' });

  try {
    const selection = figma.currentPage.selection;
    if (selection.length !== 1 || selection[0].type !== 'FRAME') {
      throw new Error('프레임 하나만 선택한 뒤 다시 실행하세요.');
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
    figma.ui.postMessage({
      type: 'error',
      text: error instanceof Error ? error.message : String(error)
    });
  } finally {
    exporting = false;
  }
};

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
