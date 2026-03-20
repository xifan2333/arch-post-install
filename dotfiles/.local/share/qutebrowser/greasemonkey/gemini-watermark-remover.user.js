// ==UserScript==
// @name         Gemini NanoBanana Watermark Remover
// @name:zh-CN   Gemini NanoBanana 图片水印移除
// @namespace    https://github.com/GargantuaX
// @version      0.1.8
// @description  Automatically removes watermarks from Gemini AI generated images
// @description:zh-CN 自动移除 Gemini AI 生成图像中的水印
// @icon         https://www.google.com/s2/favicons?domain=gemini.google.com
// @author       journey-ad
// @license      MIT
// @match        https://gemini.google.com/*
// @match        https://business.gemini.google/*
// @connect      googleusercontent.com
// @grant        GM_xmlhttpRequest
// @grant        unsafeWindow
// @run-at       document-end
// @downloadURL https://update.greasyfork.org/scripts/559574/Gemini%20NanoBanana%20Watermark%20Remover.user.js
// @updateURL https://update.greasyfork.org/scripts/559574/Gemini%20NanoBanana%20Watermark%20Remover.meta.js
// ==/UserScript==

(() => {
  // src/core/alphaMap.js
  function calculateAlphaMap(bgCaptureImageData) {
    const { width, height, data } = bgCaptureImageData;
    const alphaMap = new Float32Array(width * height);
    for (let i = 0; i < alphaMap.length; i++) {
      const idx = i * 4;
      const r = data[idx];
      const g = data[idx + 1];
      const b = data[idx + 2];
      const maxChannel = Math.max(r, g, b);
      alphaMap[i] = maxChannel / 255;
    }
    return alphaMap;
  }

  // src/core/blendModes.js
  var ALPHA_NOISE_FLOOR = 3 / 255;
  var ALPHA_THRESHOLD = 2e-3;
  var MAX_ALPHA = 0.99;
  var LOGO_VALUE = 255;
  function removeWatermark(imageData, alphaMap, position, options = {}) {
    const { x, y, width, height } = position;
    const alphaGain = Number.isFinite(options.alphaGain) && options.alphaGain > 0 ? options.alphaGain : 1;
    for (let row = 0; row < height; row++) {
      for (let col = 0; col < width; col++) {
        const imgIdx = ((y + row) * imageData.width + (x + col)) * 4;
        const alphaIdx = row * width + col;
        const rawAlpha = alphaMap[alphaIdx];
        const signalAlpha = Math.max(0, rawAlpha - ALPHA_NOISE_FLOOR) * alphaGain;
        if (signalAlpha < ALPHA_THRESHOLD) {
          continue;
        }
        const alpha = Math.min(rawAlpha * alphaGain, MAX_ALPHA);
        const oneMinusAlpha = 1 - alpha;
        for (let c = 0; c < 3; c++) {
          const watermarked = imageData.data[imgIdx + c];
          const original = (watermarked - alpha * LOGO_VALUE) / oneMinusAlpha;
          imageData.data[imgIdx + c] = Math.max(0, Math.min(255, Math.round(original)));
        }
      }
    }
  }

  // src/core/adaptiveDetector.js
  var DEFAULT_THRESHOLD = 0.35;
  var EPSILON = 1e-8;
  var clamp = (v, min, max) => Math.max(min, Math.min(max, v));
  function meanAndVariance(values) {
    let sum = 0;
    for (let i = 0; i < values.length; i++) sum += values[i];
    const mean = sum / values.length;
    let sq = 0;
    for (let i = 0; i < values.length; i++) {
      const d = values[i] - mean;
      sq += d * d;
    }
    return { mean, variance: sq / values.length };
  }
  function normalizedCrossCorrelation(a, b) {
    if (a.length !== b.length || a.length === 0) return 0;
    const statsA = meanAndVariance(a);
    const statsB = meanAndVariance(b);
    const den = Math.sqrt(statsA.variance * statsB.variance) * a.length;
    if (den < EPSILON) return 0;
    let num = 0;
    for (let i = 0; i < a.length; i++) {
      num += (a[i] - statsA.mean) * (b[i] - statsB.mean);
    }
    return num / den;
  }
  function getRegion(data, width, x, y, size) {
    const out = new Float32Array(size * size);
    for (let row = 0; row < size; row++) {
      const srcBase = (y + row) * width + x;
      const dstBase = row * size;
      for (let col = 0; col < size; col++) {
        out[dstBase + col] = data[srcBase + col];
      }
    }
    return out;
  }
  function toRegionGrayscale(imageData, region) {
    const { width, height, data } = imageData;
    const size = region.size ?? Math.min(region.width, region.height);
    if (!size || size <= 0) return new Float32Array(0);
    if (region.x < 0 || region.y < 0 || region.x + size > width || region.y + size > height) {
      return new Float32Array(0);
    }
    const out = new Float32Array(size * size);
    for (let row = 0; row < size; row++) {
      for (let col = 0; col < size; col++) {
        const idx = ((region.y + row) * width + (region.x + col)) * 4;
        out[row * size + col] = (0.2126 * data[idx] + 0.7152 * data[idx + 1] + 0.0722 * data[idx + 2]) / 255;
      }
    }
    return out;
  }
  function toGrayscale(imageData) {
    const { width, height, data } = imageData;
    const out = new Float32Array(width * height);
    for (let i = 0; i < out.length; i++) {
      const j = i * 4;
      out[i] = (0.2126 * data[j] + 0.7152 * data[j + 1] + 0.0722 * data[j + 2]) / 255;
    }
    return out;
  }
  function sobelMagnitude(gray, width, height) {
    const grad = new Float32Array(width * height);
    for (let y = 1; y < height - 1; y++) {
      for (let x = 1; x < width - 1; x++) {
        const i = y * width + x;
        const gx = -gray[i - width - 1] - 2 * gray[i - 1] - gray[i + width - 1] + gray[i - width + 1] + 2 * gray[i + 1] + gray[i + width + 1];
        const gy = -gray[i - width - 1] - 2 * gray[i - width] - gray[i - width + 1] + gray[i + width - 1] + 2 * gray[i + width] + gray[i + width + 1];
        grad[i] = Math.sqrt(gx * gx + gy * gy);
      }
    }
    return grad;
  }
  function stdDevRegion(data, width, x, y, size) {
    let sum = 0;
    let sq = 0;
    let n = 0;
    for (let row = 0; row < size; row++) {
      const base = (y + row) * width + x;
      for (let col = 0; col < size; col++) {
        const v = data[base + col];
        sum += v;
        sq += v * v;
        n++;
      }
    }
    if (n === 0) return 0;
    const mean = sum / n;
    const variance = Math.max(0, sq / n - mean * mean);
    return Math.sqrt(variance);
  }
  function buildTemplateGradient(alphaMap, size) {
    return sobelMagnitude(alphaMap, size, size);
  }
  function scoreCandidate({ gray, grad, width, height }, alphaMap, templateGrad, candidate) {
    const { x, y, size } = candidate;
    if (x < 0 || y < 0 || x + size > width || y + size > height) {
      return null;
    }
    const grayRegion = getRegion(gray, width, x, y, size);
    const gradRegion = getRegion(grad, width, x, y, size);
    const spatial = normalizedCrossCorrelation(grayRegion, alphaMap);
    const gradient = normalizedCrossCorrelation(gradRegion, templateGrad);
    let varianceScore = 0;
    if (y > 8) {
      const refY = Math.max(0, y - size);
      const refH = Math.min(size, y - refY);
      if (refH > 8) {
        const wmStd = stdDevRegion(gray, width, x, y, size);
        const refStd = stdDevRegion(gray, width, x, refY, refH);
        if (refStd > EPSILON) {
          varianceScore = clamp(1 - wmStd / refStd, 0, 1);
        }
      }
    }
    const confidence = Math.max(0, spatial) * 0.5 + Math.max(0, gradient) * 0.3 + varianceScore * 0.2;
    return {
      confidence: clamp(confidence, 0, 1),
      spatialScore: spatial,
      gradientScore: gradient,
      varianceScore
    };
  }
  function createScaleList(minSize, maxSize) {
    const set = /* @__PURE__ */ new Set();
    for (let s = minSize; s <= maxSize; s += 8) set.add(s);
    if (48 >= minSize && 48 <= maxSize) set.add(48);
    if (96 >= minSize && 96 <= maxSize) set.add(96);
    return [...set].sort((a, b) => a - b);
  }
  function getTemplate(cache, alpha96, size) {
    if (cache.has(size)) return cache.get(size);
    const alpha = size === 96 ? alpha96 : interpolateAlphaMap(alpha96, 96, size);
    const grad = buildTemplateGradient(alpha, size);
    const tpl = { alpha, grad };
    cache.set(size, tpl);
    return tpl;
  }
  function warpAlphaMap(alphaMap, size, { dx = 0, dy = 0, scale = 1 } = {}) {
    if (size <= 0) return new Float32Array(0);
    if (!Number.isFinite(dx) || !Number.isFinite(dy) || !Number.isFinite(scale) || scale <= 0) {
      return new Float32Array(0);
    }
    if (dx === 0 && dy === 0 && scale === 1) return new Float32Array(alphaMap);
    const sample = (x, y) => {
      const x0 = Math.floor(x);
      const y0 = Math.floor(y);
      const fx = x - x0;
      const fy = y - y0;
      const ix0 = clamp(x0, 0, size - 1);
      const iy0 = clamp(y0, 0, size - 1);
      const ix1 = clamp(x0 + 1, 0, size - 1);
      const iy1 = clamp(y0 + 1, 0, size - 1);
      const p00 = alphaMap[iy0 * size + ix0];
      const p10 = alphaMap[iy0 * size + ix1];
      const p01 = alphaMap[iy1 * size + ix0];
      const p11 = alphaMap[iy1 * size + ix1];
      const top = p00 + (p10 - p00) * fx;
      const bottom = p01 + (p11 - p01) * fx;
      return top + (bottom - top) * fy;
    };
    const out = new Float32Array(size * size);
    const c = (size - 1) / 2;
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const sx = (x - c) / scale + c + dx;
        const sy = (y - c) / scale + c + dy;
        out[y * size + x] = sample(sx, sy);
      }
    }
    return out;
  }
  function interpolateAlphaMap(sourceAlpha, sourceSize, targetSize) {
    if (targetSize <= 0) return new Float32Array(0);
    if (sourceSize === targetSize) return new Float32Array(sourceAlpha);
    const out = new Float32Array(targetSize * targetSize);
    const scale = (sourceSize - 1) / Math.max(1, targetSize - 1);
    for (let y = 0; y < targetSize; y++) {
      const sy = y * scale;
      const y0 = Math.floor(sy);
      const y1 = Math.min(sourceSize - 1, y0 + 1);
      const fy = sy - y0;
      for (let x = 0; x < targetSize; x++) {
        const sx = x * scale;
        const x0 = Math.floor(sx);
        const x1 = Math.min(sourceSize - 1, x0 + 1);
        const fx = sx - x0;
        const p00 = sourceAlpha[y0 * sourceSize + x0];
        const p10 = sourceAlpha[y0 * sourceSize + x1];
        const p01 = sourceAlpha[y1 * sourceSize + x0];
        const p11 = sourceAlpha[y1 * sourceSize + x1];
        const top = p00 + (p10 - p00) * fx;
        const bottom = p01 + (p11 - p01) * fx;
        out[y * targetSize + x] = top + (bottom - top) * fy;
      }
    }
    return out;
  }
  function computeRegionSpatialCorrelation({ imageData, alphaMap, region }) {
    const patch = toRegionGrayscale(imageData, region);
    if (patch.length === 0 || patch.length !== alphaMap.length) return 0;
    return normalizedCrossCorrelation(patch, alphaMap);
  }
  function computeRegionGradientCorrelation({ imageData, alphaMap, region }) {
    const patch = toRegionGrayscale(imageData, region);
    if (patch.length === 0 || patch.length !== alphaMap.length) return 0;
    const size = region.size ?? Math.min(region.width, region.height);
    if (!size || size <= 2) return 0;
    const patchGrad = sobelMagnitude(patch, size, size);
    const alphaGrad = sobelMagnitude(alphaMap, size, size);
    return normalizedCrossCorrelation(patchGrad, alphaGrad);
  }
  function shouldAttemptAdaptiveFallback({
    processedImageData,
    alphaMap,
    position,
    residualThreshold = 0.22,
    originalImageData = null,
    originalSpatialMismatchThreshold = 0
  }) {
    const residualScore = computeRegionSpatialCorrelation({
      imageData: processedImageData,
      alphaMap,
      region: {
        x: position.x,
        y: position.y,
        size: position.width ?? position.size
      }
    });
    if (residualScore >= residualThreshold) {
      return true;
    }
    if (originalImageData) {
      const originalScore = computeRegionSpatialCorrelation({
        imageData: originalImageData,
        alphaMap,
        region: {
          x: position.x,
          y: position.y,
          size: position.width ?? position.size
        }
      });
      if (originalScore <= originalSpatialMismatchThreshold) {
        return true;
      }
    }
    return false;
  }
  function detectAdaptiveWatermarkRegion({
    imageData,
    alpha96,
    defaultConfig,
    threshold = DEFAULT_THRESHOLD
  }) {
    const { width, height } = imageData;
    const gray = toGrayscale(imageData);
    const grad = sobelMagnitude(gray, width, height);
    const context = { gray, grad, width, height };
    const templateCache = /* @__PURE__ */ new Map();
    const baseSize = defaultConfig.logoSize;
    const defaultCandidate = {
      size: baseSize,
      x: width - defaultConfig.marginRight - baseSize,
      y: height - defaultConfig.marginBottom - baseSize
    };
    const defaultTemplate = getTemplate(templateCache, alpha96, baseSize);
    const defaultScore = scoreCandidate(context, defaultTemplate.alpha, defaultTemplate.grad, defaultCandidate);
    if (defaultScore && defaultScore.confidence >= threshold + 0.08) {
      return {
        found: true,
        confidence: defaultScore.confidence,
        spatialScore: defaultScore.spatialScore,
        gradientScore: defaultScore.gradientScore,
        varianceScore: defaultScore.varianceScore,
        region: defaultCandidate
      };
    }
    const minSize = clamp(Math.round(baseSize * 0.65), 24, 144);
    const maxSize = clamp(
      Math.min(Math.round(baseSize * 2.8), Math.floor(Math.min(width, height) * 0.4)),
      minSize,
      192
    );
    const scaleList = createScaleList(minSize, maxSize);
    const marginRange = Math.max(32, Math.round(baseSize * 0.75));
    const minMarginRight = clamp(defaultConfig.marginRight - marginRange, 8, width - minSize - 1);
    const maxMarginRight = clamp(defaultConfig.marginRight + marginRange, minMarginRight, width - minSize - 1);
    const minMarginBottom = clamp(defaultConfig.marginBottom - marginRange, 8, height - minSize - 1);
    const maxMarginBottom = clamp(defaultConfig.marginBottom + marginRange, minMarginBottom, height - minSize - 1);
    const topK = [];
    const pushTopK = (candidate) => {
      topK.push(candidate);
      topK.sort((a, b) => b.adjustedScore - a.adjustedScore);
      if (topK.length > 5) topK.length = 5;
    };
    for (const size of scaleList) {
      const tpl = getTemplate(templateCache, alpha96, size);
      for (let mr = minMarginRight; mr <= maxMarginRight; mr += 8) {
        const x = width - mr - size;
        if (x < 0) continue;
        for (let mb = minMarginBottom; mb <= maxMarginBottom; mb += 8) {
          const y = height - mb - size;
          if (y < 0) continue;
          const score = scoreCandidate(context, tpl.alpha, tpl.grad, { x, y, size });
          if (!score) continue;
          const adjustedScore = score.confidence * Math.min(1, Math.sqrt(size / 96));
          if (adjustedScore < 0.08) continue;
          pushTopK({
            size,
            x,
            y,
            adjustedScore
          });
        }
      }
    }
    let best = defaultScore ? {
      ...defaultCandidate,
      ...defaultScore
    } : {
      ...defaultCandidate,
      confidence: 0,
      spatialScore: 0,
      gradientScore: 0,
      varianceScore: 0
    };
    for (const coarse of topK) {
      const scaleLo = clamp(coarse.size - 10, minSize, maxSize);
      const scaleHi = clamp(coarse.size + 10, minSize, maxSize);
      for (let size = scaleLo; size <= scaleHi; size += 2) {
        const tpl = getTemplate(templateCache, alpha96, size);
        for (let x = coarse.x - 8; x <= coarse.x + 8; x += 2) {
          if (x < 0 || x + size > width) continue;
          for (let y = coarse.y - 8; y <= coarse.y + 8; y += 2) {
            if (y < 0 || y + size > height) continue;
            const score = scoreCandidate(context, tpl.alpha, tpl.grad, { x, y, size });
            if (!score) continue;
            if (score.confidence > best.confidence) {
              best = {
                x,
                y,
                size,
                ...score
              };
            }
          }
        }
      }
    }
    return {
      found: best.confidence >= threshold,
      confidence: best.confidence,
      spatialScore: best.spatialScore,
      gradientScore: best.gradientScore,
      varianceScore: best.varianceScore,
      region: {
        x: best.x,
        y: best.y,
        size: best.size
      }
    };
  }

  // src/core/watermarkConfig.js
  function detectWatermarkConfig(imageWidth, imageHeight) {
    if (imageWidth > 1024 && imageHeight > 1024) {
      return {
        logoSize: 96,
        marginRight: 64,
        marginBottom: 64
      };
    }
    return {
      logoSize: 48,
      marginRight: 32,
      marginBottom: 32
    };
  }
  function calculateWatermarkPosition(imageWidth, imageHeight, config) {
    const { logoSize, marginRight, marginBottom } = config;
    return {
      x: imageWidth - marginRight - logoSize,
      y: imageHeight - marginBottom - logoSize,
      width: logoSize,
      height: logoSize
    };
  }
  function getStandardConfig(size) {
    return size === 96 ? { logoSize: 96, marginRight: 64, marginBottom: 64 } : { logoSize: 48, marginRight: 32, marginBottom: 32 };
  }
  function getAlphaMapForConfig(config, alpha48, alpha96) {
    return config.logoSize === 96 ? alpha96 : alpha48;
  }
  function isRegionInsideImage(imageData, region) {
    return region.x >= 0 && region.y >= 0 && region.x + region.width <= imageData.width && region.y + region.height <= imageData.height;
  }
  function resolveInitialStandardConfig({
    imageData,
    defaultConfig,
    alpha48,
    alpha96,
    minSwitchScore = 0.25,
    minScoreDelta = 0.08
  }) {
    if (!imageData || !defaultConfig || !alpha48 || !alpha96) return defaultConfig;
    const fallbackConfig = getStandardConfig(48);
    const primaryConfig = defaultConfig.logoSize === 96 ? getStandardConfig(96) : fallbackConfig;
    const alternateConfig = defaultConfig.logoSize === 96 ? fallbackConfig : getStandardConfig(96);
    const primaryRegion = calculateWatermarkPosition(imageData.width, imageData.height, primaryConfig);
    const alternateRegion = calculateWatermarkPosition(imageData.width, imageData.height, alternateConfig);
    if (!isRegionInsideImage(imageData, primaryRegion)) return defaultConfig;
    const primaryScore = computeRegionSpatialCorrelation({
      imageData,
      alphaMap: getAlphaMapForConfig(primaryConfig, alpha48, alpha96),
      region: {
        x: primaryRegion.x,
        y: primaryRegion.y,
        size: primaryRegion.width
      }
    });
    if (!isRegionInsideImage(imageData, alternateRegion)) return primaryConfig;
    const alternateScore = computeRegionSpatialCorrelation({
      imageData,
      alphaMap: getAlphaMapForConfig(alternateConfig, alpha48, alpha96),
      region: {
        x: alternateRegion.x,
        y: alternateRegion.y,
        size: alternateRegion.width
      }
    });
    const shouldSwitch = alternateScore >= minSwitchScore && alternateScore > primaryScore + minScoreDelta;
    return shouldSwitch ? alternateConfig : primaryConfig;
  }

  // src/assets/bg_48.png
  var bg_48_default = "data:image/png;base64,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";

  // src/assets/bg_96.png
  var bg_96_default = "data:image/png;base64,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";

  // src/core/watermarkEngine.js
  var RESIDUAL_RECALIBRATION_THRESHOLD = 0.5;
  var MIN_SUPPRESSION_FOR_SKIP_RECALIBRATION = 0.18;
  var MIN_RECALIBRATION_SCORE_DELTA = 0.18;
  var NEAR_BLACK_THRESHOLD = 5;
  var MAX_NEAR_BLACK_RATIO_INCREASE = 0.05;
  var OUTLINE_REFINEMENT_THRESHOLD = 0.42;
  var OUTLINE_REFINEMENT_MIN_GAIN = 1.2;
  var TEMPLATE_ALIGN_SHIFTS = [-0.5, -0.25, 0, 0.25, 0.5];
  var TEMPLATE_ALIGN_SCALES = [0.99, 1, 1.01];
  var SUBPIXEL_REFINE_SHIFTS = [-0.25, 0, 0.25];
  var SUBPIXEL_REFINE_SCALES = [0.99, 1, 1.01];
  var ALPHA_GAIN_CANDIDATES = [1.05, 1.12, 1.2, 1.28, 1.36, 1.45, 1.52, 1.6, 1.7, 1.85, 2, 2.2, 2.4, 2.6];
  function createRuntimeCanvas(width, height) {
    if (typeof OffscreenCanvas !== "undefined") {
      return new OffscreenCanvas(width, height);
    }
    if (typeof document !== "undefined") {
      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      return canvas;
    }
    throw new Error("Canvas runtime not available");
  }
  function getCanvasContext2D(canvas) {
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    if (!ctx) {
      throw new Error("Failed to get 2D canvas context");
    }
    return ctx;
  }
  async function loadBackgroundCapture(source) {
    if (typeof Image !== "undefined") {
      const image = new Image();
      image.src = source;
      await image.decode();
      return image;
    }
    if (typeof createImageBitmap !== "undefined" && typeof fetch !== "undefined") {
      const response = await fetch(source);
      if (!response.ok) {
        throw new Error(`Failed to load background capture: ${response.status}`);
      }
      const blob = await response.blob();
      return await createImageBitmap(blob);
    }
    throw new Error("No image loader available in current runtime");
  }
  function cloneImageData(imageData) {
    return new ImageData(
      new Uint8ClampedArray(imageData.data),
      imageData.width,
      imageData.height
    );
  }
  function shouldRecalibrateAlphaStrength({ originalScore, processedScore, suppressionGain }) {
    return originalScore >= 0.6 && processedScore >= RESIDUAL_RECALIBRATION_THRESHOLD && suppressionGain <= MIN_SUPPRESSION_FOR_SKIP_RECALIBRATION;
  }
  function calculateNearBlackRatio(imageData, position) {
    let nearBlack = 0;
    let total = 0;
    for (let row = 0; row < position.height; row++) {
      for (let col = 0; col < position.width; col++) {
        const idx = ((position.y + row) * imageData.width + (position.x + col)) * 4;
        const r = imageData.data[idx];
        const g = imageData.data[idx + 1];
        const b = imageData.data[idx + 2];
        if (r <= NEAR_BLACK_THRESHOLD && g <= NEAR_BLACK_THRESHOLD && b <= NEAR_BLACK_THRESHOLD) {
          nearBlack++;
        }
        total++;
      }
    }
    return total > 0 ? nearBlack / total : 0;
  }
  function findBestTemplateWarp({
    originalImageData,
    alphaMap,
    position,
    baselineSpatialScore,
    baselineGradientScore
  }) {
    const size = position.width;
    if (!size || size <= 8) return null;
    let best = {
      spatialScore: baselineSpatialScore,
      gradientScore: baselineGradientScore,
      shift: { dx: 0, dy: 0, scale: 1 },
      alphaMap
    };
    for (const scale of TEMPLATE_ALIGN_SCALES) {
      for (const dy of TEMPLATE_ALIGN_SHIFTS) {
        for (const dx of TEMPLATE_ALIGN_SHIFTS) {
          if (dx === 0 && dy === 0 && scale === 1) continue;
          const warped = warpAlphaMap(alphaMap, size, { dx, dy, scale });
          const spatialScore = computeRegionSpatialCorrelation({
            imageData: originalImageData,
            alphaMap: warped,
            region: { x: position.x, y: position.y, size }
          });
          const gradientScore = computeRegionGradientCorrelation({
            imageData: originalImageData,
            alphaMap: warped,
            region: { x: position.x, y: position.y, size }
          });
          const confidence = Math.max(0, spatialScore) * 0.7 + Math.max(0, gradientScore) * 0.3;
          const bestConfidence = Math.max(0, best.spatialScore) * 0.7 + Math.max(0, best.gradientScore) * 0.3;
          if (confidence > bestConfidence + 0.01) {
            best = {
              spatialScore,
              gradientScore,
              shift: { dx, dy, scale },
              alphaMap: warped
            };
          }
        }
      }
    }
    const improvedSpatial = best.spatialScore >= baselineSpatialScore + 0.01;
    const improvedGradient = best.gradientScore >= baselineGradientScore + 0.01;
    return improvedSpatial || improvedGradient ? best : null;
  }
  function refineSubpixelOutline({
    originalImageData,
    alphaMap,
    position,
    alphaGain,
    originalNearBlackRatio,
    baselineSpatialScore,
    baselineGradientScore,
    baselineShift
  }) {
    const size = position.width;
    if (!size || size <= 8) return null;
    if (alphaGain < OUTLINE_REFINEMENT_MIN_GAIN) return null;
    const maxAllowedNearBlackRatio = Math.min(1, originalNearBlackRatio + MAX_NEAR_BLACK_RATIO_INCREASE);
    const gainCandidates = [alphaGain];
    const lower = Math.max(1, Number((alphaGain - 0.01).toFixed(2)));
    const upper = Number((alphaGain + 0.01).toFixed(2));
    if (lower !== alphaGain) gainCandidates.push(lower);
    if (upper !== alphaGain) gainCandidates.push(upper);
    const baseDx = baselineShift?.dx ?? 0;
    const baseDy = baselineShift?.dy ?? 0;
    const baseScale = baselineShift?.scale ?? 1;
    let best = null;
    for (const scaleDelta of SUBPIXEL_REFINE_SCALES) {
      const scale = Number((baseScale * scaleDelta).toFixed(4));
      for (const dyDelta of SUBPIXEL_REFINE_SHIFTS) {
        const dy = baseDy + dyDelta;
        for (const dxDelta of SUBPIXEL_REFINE_SHIFTS) {
          const dx = baseDx + dxDelta;
          const warped = warpAlphaMap(alphaMap, size, { dx, dy, scale });
          for (const gain of gainCandidates) {
            const candidate = cloneImageData(originalImageData);
            removeWatermark(candidate, warped, position, { alphaGain: gain });
            const nearBlackRatio = calculateNearBlackRatio(candidate, position);
            if (nearBlackRatio > maxAllowedNearBlackRatio) continue;
            const spatialScore = computeRegionSpatialCorrelation({
              imageData: candidate,
              alphaMap: warped,
              region: { x: position.x, y: position.y, size }
            });
            const gradientScore = computeRegionGradientCorrelation({
              imageData: candidate,
              alphaMap: warped,
              region: { x: position.x, y: position.y, size }
            });
            const cost = Math.abs(spatialScore) * 0.6 + Math.max(0, gradientScore);
            if (!best || cost < best.cost) {
              best = {
                imageData: candidate,
                alphaMap: warped,
                alphaGain: gain,
                shift: { dx, dy, scale },
                spatialScore,
                gradientScore,
                nearBlackRatio,
                cost
              };
            }
          }
        }
      }
    }
    if (!best) return null;
    const improvedGradient = best.gradientScore <= baselineGradientScore - 0.04;
    const keptSpatial = Math.abs(best.spatialScore) <= Math.abs(baselineSpatialScore) + 0.08;
    if (!improvedGradient || !keptSpatial) return null;
    return best;
  }
  function recalibrateAlphaStrength({
    originalImageData,
    alphaMap,
    position,
    originalSpatialScore,
    processedSpatialScore,
    originalNearBlackRatio
  }) {
    let bestScore = processedSpatialScore;
    let bestGain = 1;
    let bestImageData = null;
    const maxAllowedNearBlackRatio = Math.min(1, originalNearBlackRatio + MAX_NEAR_BLACK_RATIO_INCREASE);
    for (const alphaGain of ALPHA_GAIN_CANDIDATES) {
      const candidate = cloneImageData(originalImageData);
      removeWatermark(candidate, alphaMap, position, { alphaGain });
      const candidateNearBlackRatio = calculateNearBlackRatio(candidate, position);
      if (candidateNearBlackRatio > maxAllowedNearBlackRatio) {
        continue;
      }
      const score = computeRegionSpatialCorrelation({
        imageData: candidate,
        alphaMap,
        region: {
          x: position.x,
          y: position.y,
          size: position.width
        }
      });
      if (score < bestScore) {
        bestScore = score;
        bestGain = alphaGain;
        bestImageData = candidate;
      }
    }
    const refinedCandidates = [];
    for (let delta = -0.05; delta <= 0.05; delta += 0.01) {
      refinedCandidates.push(Number((bestGain + delta).toFixed(2)));
    }
    for (const alphaGain of refinedCandidates) {
      if (alphaGain <= 1 || alphaGain >= 3) continue;
      const candidate = cloneImageData(originalImageData);
      removeWatermark(candidate, alphaMap, position, { alphaGain });
      const candidateNearBlackRatio = calculateNearBlackRatio(candidate, position);
      if (candidateNearBlackRatio > maxAllowedNearBlackRatio) {
        continue;
      }
      const score = computeRegionSpatialCorrelation({
        imageData: candidate,
        alphaMap,
        region: {
          x: position.x,
          y: position.y,
          size: position.width
        }
      });
      if (score < bestScore) {
        bestScore = score;
        bestGain = alphaGain;
        bestImageData = candidate;
      }
    }
    const scoreDelta = processedSpatialScore - bestScore;
    if (!bestImageData || scoreDelta < MIN_RECALIBRATION_SCORE_DELTA) {
      return null;
    }
    return {
      imageData: bestImageData,
      alphaGain: bestGain,
      processedSpatialScore: bestScore,
      suppressionGain: originalSpatialScore - bestScore
    };
  }
  var WatermarkEngine = class _WatermarkEngine {
    constructor(bgCaptures) {
      this.bgCaptures = bgCaptures;
      this.alphaMaps = {};
    }
    static async create() {
      const [bg48, bg96] = await Promise.all([
        loadBackgroundCapture(bg_48_default),
        loadBackgroundCapture(bg_96_default)
      ]);
      return new _WatermarkEngine({ bg48, bg96 });
    }
    /**
     * Get alpha map from background captured image based on watermark size
     * @param {number} size - Watermark size (48 or 96)
     * @returns {Promise<Float32Array>} Alpha map
     */
    async getAlphaMap(size) {
      if (size !== 48 && size !== 96) {
        if (this.alphaMaps[size]) return this.alphaMaps[size];
        const alpha96 = await this.getAlphaMap(96);
        const interpolated = interpolateAlphaMap(alpha96, 96, size);
        this.alphaMaps[size] = interpolated;
        return interpolated;
      }
      if (this.alphaMaps[size]) {
        return this.alphaMaps[size];
      }
      const bgImage = size === 48 ? this.bgCaptures.bg48 : this.bgCaptures.bg96;
      const canvas = createRuntimeCanvas(size, size);
      const ctx = getCanvasContext2D(canvas);
      ctx.drawImage(bgImage, 0, 0);
      const imageData = ctx.getImageData(0, 0, size, size);
      const alphaMap = calculateAlphaMap(imageData);
      this.alphaMaps[size] = alphaMap;
      return alphaMap;
    }
    /**
     * Remove watermark from image based on watermark size
     * @param {HTMLImageElement|HTMLCanvasElement} image - Input image
     * @returns {Promise<HTMLCanvasElement>} Processed canvas
     */
    async removeWatermarkFromImage(image, options = {}) {
      const adaptiveMode = options.adaptiveMode || "auto";
      const canvas = createRuntimeCanvas(image.width, image.height);
      const ctx = getCanvasContext2D(canvas);
      ctx.drawImage(image, 0, 0);
      const originalImageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      const defaultConfig = detectWatermarkConfig(canvas.width, canvas.height);
      const alpha48 = await this.getAlphaMap(48);
      const alpha96 = await this.getAlphaMap(96);
      const resolvedConfig = resolveInitialStandardConfig({
        imageData: originalImageData,
        defaultConfig,
        alpha48,
        alpha96
      });
      let config = resolvedConfig;
      let position = calculateWatermarkPosition(canvas.width, canvas.height, config);
      let alphaMap = config.logoSize === 96 ? alpha96 : alpha48;
      let source = "standard";
      let adaptiveConfidence = null;
      let alphaGain = 1;
      const fixedImageData = cloneImageData(originalImageData);
      removeWatermark(fixedImageData, alphaMap, position);
      let finalImageData = fixedImageData;
      const shouldFallback = adaptiveMode === "always" ? true : shouldAttemptAdaptiveFallback({
        processedImageData: fixedImageData,
        alphaMap,
        position,
        originalImageData,
        originalSpatialMismatchThreshold: 0
      });
      if (shouldFallback) {
        const adaptive = detectAdaptiveWatermarkRegion({
          imageData: originalImageData,
          alpha96,
          defaultConfig: config
        });
        if (adaptive.found) {
          adaptiveConfidence = adaptive.confidence;
          const size = adaptive.region.size;
          const adaptivePosition = {
            x: adaptive.region.x,
            y: adaptive.region.y,
            width: size,
            height: size
          };
          const positionDelta = Math.abs(adaptivePosition.x - position.x) + Math.abs(adaptivePosition.y - position.y) + Math.abs(adaptivePosition.width - position.width);
          if (positionDelta >= 4) {
            position = adaptivePosition;
            alphaMap = await this.getAlphaMap(size);
            config = {
              logoSize: size,
              marginRight: canvas.width - adaptivePosition.x - size,
              marginBottom: canvas.height - adaptivePosition.y - size
            };
            source = "adaptive";
            const adaptiveImageData = cloneImageData(originalImageData);
            removeWatermark(adaptiveImageData, alphaMap, position);
            finalImageData = adaptiveImageData;
          }
        }
      }
      let originalSpatialScore = computeRegionSpatialCorrelation({
        imageData: originalImageData,
        alphaMap,
        region: {
          x: position.x,
          y: position.y,
          size: position.width
        }
      });
      let originalGradientScore = computeRegionGradientCorrelation({
        imageData: originalImageData,
        alphaMap,
        region: {
          x: position.x,
          y: position.y,
          size: position.width
        }
      });
      const templateWarp = findBestTemplateWarp({
        originalImageData,
        alphaMap,
        position,
        baselineSpatialScore: originalSpatialScore,
        baselineGradientScore: originalGradientScore
      });
      if (templateWarp) {
        alphaMap = templateWarp.alphaMap;
        originalSpatialScore = templateWarp.spatialScore;
        originalGradientScore = templateWarp.gradientScore;
      }
      const processedSpatialScore = computeRegionSpatialCorrelation({
        imageData: finalImageData,
        alphaMap,
        region: {
          x: position.x,
          y: position.y,
          size: position.width
        }
      });
      const processedGradientScore = computeRegionGradientCorrelation({
        imageData: finalImageData,
        alphaMap,
        region: {
          x: position.x,
          y: position.y,
          size: position.width
        }
      });
      let finalProcessedSpatialScore = processedSpatialScore;
      let finalProcessedGradientScore = processedGradientScore;
      let suppressionGain = originalSpatialScore - finalProcessedSpatialScore;
      if (shouldRecalibrateAlphaStrength({
        originalScore: originalSpatialScore,
        processedScore: finalProcessedSpatialScore,
        suppressionGain
      })) {
        const originalNearBlackRatio = calculateNearBlackRatio(originalImageData, position);
        const recalibrated = recalibrateAlphaStrength({
          originalImageData,
          alphaMap,
          position,
          originalSpatialScore,
          processedSpatialScore: finalProcessedSpatialScore,
          originalNearBlackRatio
        });
        if (recalibrated) {
          finalImageData = recalibrated.imageData;
          alphaGain = recalibrated.alphaGain;
          finalProcessedSpatialScore = recalibrated.processedSpatialScore;
          suppressionGain = recalibrated.suppressionGain;
          source = source === "adaptive" ? "adaptive+gain" : "standard+gain";
        }
      }
      if (finalProcessedSpatialScore <= 0.3 && finalProcessedGradientScore >= OUTLINE_REFINEMENT_THRESHOLD) {
        const originalNearBlackRatio = calculateNearBlackRatio(originalImageData, position);
        const baselineShift = templateWarp?.shift ?? { dx: 0, dy: 0, scale: 1 };
        const refined = refineSubpixelOutline({
          originalImageData,
          alphaMap,
          position,
          alphaGain,
          originalNearBlackRatio,
          baselineSpatialScore: finalProcessedSpatialScore,
          baselineGradientScore: finalProcessedGradientScore,
          baselineShift
        });
        if (refined) {
          finalImageData = refined.imageData;
          alphaMap = refined.alphaMap;
          alphaGain = refined.alphaGain;
          finalProcessedSpatialScore = refined.spatialScore;
          finalProcessedGradientScore = refined.gradientScore;
          suppressionGain = originalSpatialScore - finalProcessedSpatialScore;
          source = `${source}+subpixel`;
          canvas.__watermarkMeta = canvas.__watermarkMeta || {};
          canvas.__watermarkMeta.subpixelShift = refined.shift;
        }
      }
      ctx.putImageData(finalImageData, 0, 0);
      canvas.__watermarkMeta = {
        size: position.width,
        position: {
          x: position.x,
          y: position.y,
          width: position.width,
          height: position.height
        },
        config: {
          logoSize: config.logoSize,
          marginRight: config.marginRight,
          marginBottom: config.marginBottom
        },
        detection: {
          adaptiveConfidence,
          originalSpatialScore,
          originalGradientScore,
          processedSpatialScore: finalProcessedSpatialScore,
          processedGradientScore: finalProcessedGradientScore,
          suppressionGain
        },
        templateWarp: templateWarp?.shift ?? null,
        alphaGain,
        source
      };
      return canvas;
    }
    /**
     * Get watermark information (for display)
     * @param {number} imageWidth - Image width
     * @param {number} imageHeight - Image height
     * @returns {Object} Watermark information {size, position, config}
     */
    getWatermarkInfo(imageWidth, imageHeight) {
      const config = detectWatermarkConfig(imageWidth, imageHeight);
      const position = calculateWatermarkPosition(imageWidth, imageHeight, config);
      return {
        size: config.logoSize,
        position,
        config
      };
    }
  };

  // src/core/canvasBlob.js
  async function canvasToBlob(canvas, type = "image/png") {
    if (typeof canvas?.convertToBlob === "function") {
      return await canvas.convertToBlob({ type });
    }
    if (typeof canvas?.toBlob === "function") {
      return await new Promise((resolve, reject) => {
        canvas.toBlob((blob) => {
          if (blob) {
            resolve(blob);
          } else {
            reject(new Error("Failed to encode image blob"));
          }
        }, type);
      });
    }
    throw new Error("Canvas blob export API is unavailable");
  }

  // src/userscript/urlUtils.js
  function isGoogleusercontentHost(hostname) {
    return hostname === "googleusercontent.com" || hostname.endsWith(".googleusercontent.com");
  }
  function hasGeminiAssetPath(pathname) {
    return /^\/rd-[^/]+\//.test(pathname);
  }
  function isGeminiGeneratedAssetUrl(url) {
    if (typeof url !== "string" || url.length === 0) return false;
    try {
      const parsed = new URL(url);
      return isGoogleusercontentHost(parsed.hostname) && hasGeminiAssetPath(parsed.pathname);
    } catch {
      return false;
    }
  }
  function normalizeGoogleusercontentImageUrl(url) {
    if (!isGeminiGeneratedAssetUrl(url)) return url;
    try {
      const parsed = new URL(url);
      const path = parsed.pathname;
      const tailTransform = path.match(/=([^/?#=]+)$/);
      if (tailTransform && /^(?:s|w|h)\d+/i.test(tailTransform[1])) {
        const keepDownloadFlag = tailTransform[1].endsWith("-d") ? "-d" : "";
        parsed.pathname = `${path.slice(0, tailTransform.index)}=s0${keepDownloadFlag}`;
        return parsed.toString();
      }
      const sizeTransformAtTail = /=s\d+([^/]*)$/;
      if (sizeTransformAtTail.test(path)) {
        parsed.pathname = path.replace(sizeTransformAtTail, "=s0$1");
        return parsed.toString();
      }
      parsed.pathname = `${path}=s0`;
      return parsed.toString();
    } catch {
      return url;
    }
  }

  // src/userscript/trustedTypes.js
  var USERSCRIPT_TRUSTED_TYPES_POLICY = "gemini-watermark-remover";
  function toWorkerScriptUrl(url, env = globalThis) {
    const trustedTypesApi = env?.trustedTypes;
    if (!trustedTypesApi || typeof trustedTypesApi.createPolicy !== "function") {
      return url;
    }
    try {
      const existingPolicy = typeof trustedTypesApi.getPolicy === "function" ? trustedTypesApi.getPolicy(USERSCRIPT_TRUSTED_TYPES_POLICY) : null;
      const policy = existingPolicy || trustedTypesApi.createPolicy(
        USERSCRIPT_TRUSTED_TYPES_POLICY,
        { createScriptURL: (value) => value }
      );
      if (!policy || typeof policy.createScriptURL !== "function") return null;
      return policy.createScriptURL(url);
    } catch {
      return null;
    }
  }

  // src/userscript/runtimeFlags.js
  var INLINE_WORKER_DEFAULT_ENABLED = true ? false : false;
  function shouldUseInlineWorker(workerCode, env = globalThis) {
    const forceEnable = env?.__GWR_FORCE_INLINE_WORKER__ === true;
    if (!INLINE_WORKER_DEFAULT_ENABLED && !forceEnable) return false;
    if (typeof workerCode !== "string" || workerCode.length === 0) return false;
    return typeof env?.Worker !== "undefined" && typeof env?.Blob !== "undefined";
  }

  // src/userscript/retryPolicy.js
  var MAX_PROCESS_RETRIES = 3;
  var BASE_RETRY_DELAY_MS = 1e3;
  var MAX_RETRY_DELAY_MS = 3e4;
  var RETRY_JITTER_MS = 300;
  var toSafeInteger = (value, fallback = 0) => {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  };
  function readRetryState(dataset = {}) {
    const failureCount = Math.max(0, toSafeInteger(dataset.watermarkFailureCount, 0));
    const retryExhausted = dataset.watermarkRetryExhausted === "true" || failureCount >= MAX_PROCESS_RETRIES;
    const nextRetryAt = retryExhausted ? 0 : Math.max(0, toSafeInteger(dataset.watermarkNextRetryAt, 0));
    return {
      failureCount,
      nextRetryAt,
      retryExhausted
    };
  }
  function shouldProcessNow(state, now = Date.now()) {
    if (!state || state.retryExhausted) return false;
    return now >= state.nextRetryAt;
  }
  function resetRetryState(dataset = {}) {
    dataset.watermarkFailureCount = "0";
    dataset.watermarkNextRetryAt = "0";
    dataset.watermarkRetryExhausted = "false";
  }
  function computeRetryDelayMs(failureCount, { random = Math.random } = {}) {
    const safeFailures = Math.max(1, toSafeInteger(failureCount, 1));
    const exponential = Math.min(MAX_RETRY_DELAY_MS, BASE_RETRY_DELAY_MS * 2 ** (safeFailures - 1));
    const jitter = Math.floor(Math.max(0, random()) * RETRY_JITTER_MS);
    return exponential + jitter;
  }
  function registerProcessFailure(dataset = {}, { now = Date.now(), random = Math.random } = {}) {
    const current = readRetryState(dataset);
    const failureCount = current.failureCount + 1;
    dataset.watermarkFailureCount = String(failureCount);
    if (failureCount >= MAX_PROCESS_RETRIES) {
      dataset.watermarkRetryExhausted = "true";
      dataset.watermarkNextRetryAt = "0";
      return {
        failureCount,
        exhausted: true,
        delayMs: 0,
        nextRetryAt: 0
      };
    }
    const delayMs = computeRetryDelayMs(failureCount, { random });
    const nextRetryAt = now + delayMs;
    dataset.watermarkRetryExhausted = "false";
    dataset.watermarkNextRetryAt = String(nextRetryAt);
    return {
      failureCount,
      exhausted: false,
      delayMs,
      nextRetryAt
    };
  }

  // src/userscript/index.js
  var USERSCRIPT_WORKER_CODE = true ? '(()=>{function z(e){let{width:t,height:n,data:r}=e,a=new Float32Array(t*n);for(let c=0;c<a.length;c++){let o=c*4,l=r[o],s=r[o+1],f=r[o+2],h=Math.max(l,s,f);a[c]=h/255}return a}var mt=.011764705882352941,pt=.002,xt=.99,St=255;function L(e,t,n,r={}){let{x:a,y:c,width:o,height:l}=n,s=Number.isFinite(r.alphaGain)&&r.alphaGain>0?r.alphaGain:1;for(let f=0;f<l;f++)for(let h=0;h<o;h++){let u=((c+f)*e.width+(a+h))*4,i=f*o+h,d=t[i];if(Math.max(0,d-mt)*s<pt)continue;let x=Math.min(d*s,xt),S=1-x;for(let w=0;w<3;w++){let v=(e.data[u+w]-x*St)/S;e.data[u+w]=Math.max(0,Math.min(255,Math.round(v)))}}}var G=(e,t,n)=>Math.max(t,Math.min(n,e));function K(e){let t=0;for(let a=0;a<e.length;a++)t+=e[a];let n=t/e.length,r=0;for(let a=0;a<e.length;a++){let c=e[a]-n;r+=c*c}return{mean:n,variance:r/e.length}}function W(e,t){if(e.length!==t.length||e.length===0)return 0;let n=K(e),r=K(t),a=Math.sqrt(n.variance*r.variance)*e.length;if(a<1e-8)return 0;let c=0;for(let o=0;o<e.length;o++)c+=(e[o]-n.mean)*(t[o]-r.mean);return c/a}function $(e,t,n,r,a){let c=new Float32Array(a*a);for(let o=0;o<a;o++){let l=(r+o)*t+n,s=o*a;for(let f=0;f<a;f++)c[s+f]=e[l+f]}return c}function et(e,t){let{width:n,height:r,data:a}=e,c=t.size??Math.min(t.width,t.height);if(!c||c<=0)return new Float32Array(0);if(t.x<0||t.y<0||t.x+c>n||t.y+c>r)return new Float32Array(0);let o=new Float32Array(c*c);for(let l=0;l<c;l++)for(let s=0;s<c;s++){let f=((t.y+l)*n+(t.x+s))*4;o[l*c+s]=(.2126*a[f]+.7152*a[f+1]+.0722*a[f+2])/255}return o}function wt(e){let{width:t,height:n,data:r}=e,a=new Float32Array(t*n);for(let c=0;c<a.length;c++){let o=c*4;a[c]=(.2126*r[o]+.7152*r[o+1]+.0722*r[o+2])/255}return a}function O(e,t,n){let r=new Float32Array(t*n);for(let a=1;a<n-1;a++)for(let c=1;c<t-1;c++){let o=a*t+c,l=-e[o-t-1]-2*e[o-1]-e[o+t-1]+e[o-t+1]+2*e[o+1]+e[o+t+1],s=-e[o-t-1]-2*e[o-t]-e[o-t+1]+e[o+t-1]+2*e[o+t]+e[o+t+1];r[o]=Math.sqrt(l*l+s*s)}return r}function tt(e,t,n,r,a){let c=0,o=0,l=0;for(let h=0;h<a;h++){let u=(r+h)*t+n;for(let i=0;i<a;i++){let d=e[u+i];c+=d,o+=d*d,l++}}if(l===0)return 0;let s=c/l,f=Math.max(0,o/l-s*s);return Math.sqrt(f)}function yt(e,t){return O(e,t,t)}function J({gray:e,grad:t,width:n,height:r},a,c,o){let{x:l,y:s,size:f}=o;if(l<0||s<0||l+f>n||s+f>r)return null;let h=$(e,n,l,s,f),u=$(t,n,l,s,f),i=W(h,a),d=W(u,c),g=0;if(s>8){let S=Math.max(0,s-f),w=Math.min(f,s-S);if(w>8){let b=tt(e,n,l,s,f),v=tt(e,n,l,S,w);v>1e-8&&(g=G(1-b/v,0,1))}}let x=Math.max(0,i)*.5+Math.max(0,d)*.3+g*.2;return{confidence:G(x,0,1),spatialScore:i,gradientScore:d,varianceScore:g}}function Mt(e,t){let n=new Set;for(let r=e;r<=t;r+=8)n.add(r);return 48>=e&&48<=t&&n.add(48),96>=e&&96<=t&&n.add(96),[...n].sort((r,a)=>r-a)}function V(e,t,n){if(e.has(n))return e.get(n);let r=n===96?t:Q(t,96,n),a=yt(r,n),c={alpha:r,grad:a};return e.set(n,c),c}function X(e,t,{dx:n=0,dy:r=0,scale:a=1}={}){if(t<=0)return new Float32Array(0);if(!Number.isFinite(n)||!Number.isFinite(r)||!Number.isFinite(a)||a<=0)return new Float32Array(0);if(n===0&&r===0&&a===1)return new Float32Array(e);let c=(s,f)=>{let h=Math.floor(s),u=Math.floor(f),i=s-h,d=f-u,g=G(h,0,t-1),x=G(u,0,t-1),S=G(h+1,0,t-1),w=G(u+1,0,t-1),b=e[x*t+g],v=e[x*t+S],A=e[w*t+g],F=e[w*t+S],D=b+(v-b)*i,k=A+(F-A)*i;return D+(k-D)*d},o=new Float32Array(t*t),l=(t-1)/2;for(let s=0;s<t;s++)for(let f=0;f<t;f++){let h=(f-l)/a+l+n,u=(s-l)/a+l+r;o[s*t+f]=c(h,u)}return o}function Q(e,t,n){if(n<=0)return new Float32Array(0);if(t===n)return new Float32Array(e);let r=new Float32Array(n*n),a=(t-1)/Math.max(1,n-1);for(let c=0;c<n;c++){let o=c*a,l=Math.floor(o),s=Math.min(t-1,l+1),f=o-l;for(let h=0;h<n;h++){let u=h*a,i=Math.floor(u),d=Math.min(t-1,i+1),g=u-i,x=e[l*t+i],S=e[l*t+d],w=e[s*t+i],b=e[s*t+d],v=x+(S-x)*g,A=w+(b-w)*g;r[c*n+h]=v+(A-v)*f}}return r}function B({imageData:e,alphaMap:t,region:n}){let r=et(e,n);return r.length===0||r.length!==t.length?0:W(r,t)}function C({imageData:e,alphaMap:t,region:n}){let r=et(e,n);if(r.length===0||r.length!==t.length)return 0;let a=n.size??Math.min(n.width,n.height);if(!a||a<=2)return 0;let c=O(r,a,a),o=O(t,a,a);return W(c,o)}function nt({processedImageData:e,alphaMap:t,position:n,residualThreshold:r=.22,originalImageData:a=null,originalSpatialMismatchThreshold:c=0}){return!!(B({imageData:e,alphaMap:t,region:{x:n.x,y:n.y,size:n.width??n.size}})>=r||a&&B({imageData:a,alphaMap:t,region:{x:n.x,y:n.y,size:n.width??n.size}})<=c)}function at({imageData:e,alpha96:t,defaultConfig:n,threshold:r=.35}){let{width:a,height:c}=e,o=wt(e),l=O(o,a,c),s={gray:o,grad:l,width:a,height:c},f=new Map,h=n.logoSize,u={size:h,x:a-n.marginRight-h,y:c-n.marginBottom-h},i=V(f,t,h),d=J(s,i.alpha,i.grad,u);if(d&&d.confidence>=r+.08)return{found:!0,confidence:d.confidence,spatialScore:d.spatialScore,gradientScore:d.gradientScore,varianceScore:d.varianceScore,region:u};let g=G(Math.round(h*.65),24,144),x=G(Math.min(Math.round(h*2.8),Math.floor(Math.min(a,c)*.4)),g,192),S=Mt(g,x),w=Math.max(32,Math.round(h*.75)),b=G(n.marginRight-w,8,a-g-1),v=G(n.marginRight+w,b,a-g-1),A=G(n.marginBottom-w,8,c-g-1),F=G(n.marginBottom+w,A,c-g-1),D=[],k=m=>{D.push(m),D.sort((E,R)=>R.adjustedScore-E.adjustedScore),D.length>5&&(D.length=5)};for(let m of S){let E=V(f,t,m);for(let R=b;R<=v;R+=8){let y=a-R-m;if(!(y<0))for(let M=A;M<=F;M+=8){let p=c-M-m;if(p<0)continue;let _=J(s,E.alpha,E.grad,{x:y,y:p,size:m});if(!_)continue;let N=_.confidence*Math.min(1,Math.sqrt(m/96));N<.08||k({size:m,x:y,y:p,adjustedScore:N})}}}let I=d?{...u,...d}:{...u,confidence:0,spatialScore:0,gradientScore:0,varianceScore:0};for(let m of D){let E=G(m.size-10,g,x),R=G(m.size+10,g,x);for(let y=E;y<=R;y+=2){let M=V(f,t,y);for(let p=m.x-8;p<=m.x+8;p+=2)if(!(p<0||p+y>a))for(let _=m.y-8;_<=m.y+8;_+=2){if(_<0||_+y>c)continue;let N=J(s,M.alpha,M.grad,{x:p,y:_,size:y});N&&N.confidence>I.confidence&&(I={x:p,y:_,size:y,...N})}}}return{found:I.confidence>=r,confidence:I.confidence,spatialScore:I.spatialScore,gradientScore:I.gradientScore,varianceScore:I.varianceScore,region:{x:I.x,y:I.y,size:I.size}}}function H(e,t){return e>1024&&t>1024?{logoSize:96,marginRight:64,marginBottom:64}:{logoSize:48,marginRight:32,marginBottom:32}}function T(e,t,n){let{logoSize:r,marginRight:a,marginBottom:c}=n;return{x:e-a-r,y:t-c-r,width:r,height:r}}function Y(e){return e===96?{logoSize:96,marginRight:64,marginBottom:64}:{logoSize:48,marginRight:32,marginBottom:32}}function ot(e,t,n){return e.logoSize===96?n:t}function rt(e,t){return t.x>=0&&t.y>=0&&t.x+t.width<=e.width&&t.y+t.height<=e.height}function ct({imageData:e,defaultConfig:t,alpha48:n,alpha96:r,minSwitchScore:a=.25,minScoreDelta:c=.08}){if(!e||!t||!n||!r)return t;let o=Y(48),l=t.logoSize===96?Y(96):o,s=t.logoSize===96?o:Y(96),f=T(e.width,e.height,l),h=T(e.width,e.height,s);if(!rt(e,f))return t;let u=B({imageData:e,alphaMap:ot(l,n,r),region:{x:f.x,y:f.y,size:f.width}});if(!rt(e,h))return l;let i=B({imageData:e,alphaMap:ot(s,n,r),region:{x:h.x,y:h.y,size:h.width}});return i>=a&&i>u+c?s:l}var it="data:image/png;base64,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";var st="data:image/png;base64,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";var Dt=.5,Rt=.18,It=.18,q=5,gt=.05,vt=.42,Et=1.2,lt=[-.5,-.25,0,.25,.5],Gt=[.99,1,1.01],ft=[-.25,0,.25],_t=[.99,1,1.01],Bt=[1.05,1.12,1.2,1.28,1.36,1.45,1.52,1.6,1.7,1.85,2,2.2,2.4,2.6];function dt(e,t){if(typeof OffscreenCanvas<"u")return new OffscreenCanvas(e,t);if(typeof document<"u"){let n=document.createElement("canvas");return n.width=e,n.height=t,n}throw new Error("Canvas runtime not available")}function ht(e){let t=e.getContext("2d",{willReadFrequently:!0});if(!t)throw new Error("Failed to get 2D canvas context");return t}async function ut(e){if(typeof Image<"u"){let t=new Image;return t.src=e,await t.decode(),t}if(typeof createImageBitmap<"u"&&typeof fetch<"u"){let t=await fetch(e);if(!t.ok)throw new Error(`Failed to load background capture: ${t.status}`);let n=await t.blob();return await createImageBitmap(n)}throw new Error("No image loader available in current runtime")}function U(e){return new ImageData(new Uint8ClampedArray(e.data),e.width,e.height)}function Ft({originalScore:e,processedScore:t,suppressionGain:n}){return e>=.6&&t>=Dt&&n<=Rt}function P(e,t){let n=0,r=0;for(let a=0;a<t.height;a++)for(let c=0;c<t.width;c++){let o=((t.y+a)*e.width+(t.x+c))*4,l=e.data[o],s=e.data[o+1],f=e.data[o+2];l<=q&&s<=q&&f<=q&&n++,r++}return r>0?n/r:0}function Nt({originalImageData:e,alphaMap:t,position:n,baselineSpatialScore:r,baselineGradientScore:a}){let c=n.width;if(!c||c<=8)return null;let o={spatialScore:r,gradientScore:a,shift:{dx:0,dy:0,scale:1},alphaMap:t};for(let f of Gt)for(let h of lt)for(let u of lt){if(u===0&&h===0&&f===1)continue;let i=X(t,c,{dx:u,dy:h,scale:f}),d=B({imageData:e,alphaMap:i,region:{x:n.x,y:n.y,size:c}}),g=C({imageData:e,alphaMap:i,region:{x:n.x,y:n.y,size:c}}),x=Math.max(0,d)*.7+Math.max(0,g)*.3,S=Math.max(0,o.spatialScore)*.7+Math.max(0,o.gradientScore)*.3;x>S+.01&&(o={spatialScore:d,gradientScore:g,shift:{dx:u,dy:h,scale:f},alphaMap:i})}let l=o.spatialScore>=r+.01,s=o.gradientScore>=a+.01;return l||s?o:null}function kt({originalImageData:e,alphaMap:t,position:n,alphaGain:r,originalNearBlackRatio:a,baselineSpatialScore:c,baselineGradientScore:o,baselineShift:l}){let s=n.width;if(!s||s<=8||r<Et)return null;let f=Math.min(1,a+gt),h=[r],u=Math.max(1,Number((r-.01).toFixed(2))),i=Number((r+.01).toFixed(2));u!==r&&h.push(u),i!==r&&h.push(i);let d=l?.dx??0,g=l?.dy??0,x=l?.scale??1,S=null;for(let v of _t){let A=Number((x*v).toFixed(4));for(let F of ft){let D=g+F;for(let k of ft){let I=d+k,m=X(t,s,{dx:I,dy:D,scale:A});for(let E of h){let R=U(e);L(R,m,n,{alphaGain:E});let y=P(R,n);if(y>f)continue;let M=B({imageData:R,alphaMap:m,region:{x:n.x,y:n.y,size:s}}),p=C({imageData:R,alphaMap:m,region:{x:n.x,y:n.y,size:s}}),_=Math.abs(M)*.6+Math.max(0,p);(!S||_<S.cost)&&(S={imageData:R,alphaMap:m,alphaGain:E,shift:{dx:I,dy:D,scale:A},spatialScore:M,gradientScore:p,nearBlackRatio:y,cost:_})}}}}if(!S)return null;let w=S.gradientScore<=o-.04,b=Math.abs(S.spatialScore)<=Math.abs(c)+.08;return!w||!b?null:S}function Lt({originalImageData:e,alphaMap:t,position:n,originalSpatialScore:r,processedSpatialScore:a,originalNearBlackRatio:c}){let o=a,l=1,s=null,f=Math.min(1,c+gt);for(let i of Bt){let d=U(e);if(L(d,t,n,{alphaGain:i}),P(d,n)>f)continue;let x=B({imageData:d,alphaMap:t,region:{x:n.x,y:n.y,size:n.width}});x<o&&(o=x,l=i,s=d)}let h=[];for(let i=-.05;i<=.05;i+=.01)h.push(Number((l+i).toFixed(2)));for(let i of h){if(i<=1||i>=3)continue;let d=U(e);if(L(d,t,n,{alphaGain:i}),P(d,n)>f)continue;let x=B({imageData:d,alphaMap:t,region:{x:n.x,y:n.y,size:n.width}});x<o&&(o=x,l=i,s=d)}let u=a-o;return!s||u<It?null:{imageData:s,alphaGain:l,processedSpatialScore:o,suppressionGain:r-o}}var j=class e{constructor(t){this.bgCaptures=t,this.alphaMaps={}}static async create(){let[t,n]=await Promise.all([ut(it),ut(st)]);return new e({bg48:t,bg96:n})}async getAlphaMap(t){if(t!==48&&t!==96){if(this.alphaMaps[t])return this.alphaMaps[t];let l=await this.getAlphaMap(96),s=Q(l,96,t);return this.alphaMaps[t]=s,s}if(this.alphaMaps[t])return this.alphaMaps[t];let n=t===48?this.bgCaptures.bg48:this.bgCaptures.bg96,r=dt(t,t),a=ht(r);a.drawImage(n,0,0);let c=a.getImageData(0,0,t,t),o=z(c);return this.alphaMaps[t]=o,o}async removeWatermarkFromImage(t,n={}){let r=n.adaptiveMode||"auto",a=dt(t.width,t.height),c=ht(a);c.drawImage(t,0,0);let o=c.getImageData(0,0,a.width,a.height),l=H(a.width,a.height),s=await this.getAlphaMap(48),f=await this.getAlphaMap(96),u=ct({imageData:o,defaultConfig:l,alpha48:s,alpha96:f}),i=T(a.width,a.height,u),d=u.logoSize===96?f:s,g="standard",x=null,S=1,w=U(o);L(w,d,i);let b=w;if(r==="always"?!0:nt({processedImageData:w,alphaMap:d,position:i,originalImageData:o,originalSpatialMismatchThreshold:0})){let y=at({imageData:o,alpha96:f,defaultConfig:u});if(y.found){x=y.confidence;let M=y.region.size,p={x:y.region.x,y:y.region.y,width:M,height:M};if(Math.abs(p.x-i.x)+Math.abs(p.y-i.y)+Math.abs(p.width-i.width)>=4){i=p,d=await this.getAlphaMap(M),u={logoSize:M,marginRight:a.width-p.x-M,marginBottom:a.height-p.y-M},g="adaptive";let N=U(o);L(N,d,i),b=N}}}let A=B({imageData:o,alphaMap:d,region:{x:i.x,y:i.y,size:i.width}}),F=C({imageData:o,alphaMap:d,region:{x:i.x,y:i.y,size:i.width}}),D=Nt({originalImageData:o,alphaMap:d,position:i,baselineSpatialScore:A,baselineGradientScore:F});D&&(d=D.alphaMap,A=D.spatialScore,F=D.gradientScore);let k=B({imageData:b,alphaMap:d,region:{x:i.x,y:i.y,size:i.width}}),I=C({imageData:b,alphaMap:d,region:{x:i.x,y:i.y,size:i.width}}),m=k,E=I,R=A-m;if(Ft({originalScore:A,processedScore:m,suppressionGain:R})){let y=P(o,i),M=Lt({originalImageData:o,alphaMap:d,position:i,originalSpatialScore:A,processedSpatialScore:m,originalNearBlackRatio:y});M&&(b=M.imageData,S=M.alphaGain,m=M.processedSpatialScore,R=M.suppressionGain,g=g==="adaptive"?"adaptive+gain":"standard+gain")}if(m<=.3&&E>=vt){let y=P(o,i),M=D?.shift??{dx:0,dy:0,scale:1},p=kt({originalImageData:o,alphaMap:d,position:i,alphaGain:S,originalNearBlackRatio:y,baselineSpatialScore:m,baselineGradientScore:E,baselineShift:M});p&&(b=p.imageData,d=p.alphaMap,S=p.alphaGain,m=p.spatialScore,E=p.gradientScore,R=A-m,g=`${g}+subpixel`,a.__watermarkMeta=a.__watermarkMeta||{},a.__watermarkMeta.subpixelShift=p.shift)}return c.putImageData(b,0,0),a.__watermarkMeta={size:i.width,position:{x:i.x,y:i.y,width:i.width,height:i.height},config:{logoSize:u.logoSize,marginRight:u.marginRight,marginBottom:u.marginBottom},detection:{adaptiveConfidence:x,originalSpatialScore:A,originalGradientScore:F,processedSpatialScore:m,processedGradientScore:E,suppressionGain:R},templateWarp:D?.shift??null,alphaGain:S,source:g},a}getWatermarkInfo(t,n){let r=H(t,n),a=T(t,n,r);return{size:r.logoSize,position:a,config:r}}};var Z=null;function Tt(){return Z||(Z=j.create()),Z}function Ct(e){return e?{message:e.message||String(e),stack:e.stack||null}:{message:"Unknown error"}}async function Ut(e){if(typeof e.convertToBlob=="function")return await e.convertToBlob({type:"image/png"});if(typeof e.toBlob=="function")return await new Promise((t,n)=>{e.toBlob(r=>{r?t(r):n(new Error("Failed to encode PNG blob"))},"image/png")});throw new Error("Canvas blob export API is unavailable")}self.addEventListener("message",async e=>{let t=e.data;if(!t||t.type!=="process-image")return;let{id:n,inputBuffer:r,mimeType:a,options:c}=t;try{let o=await Tt(),l=new Blob([r],{type:a||"image/png"}),s=await createImageBitmap(l),f=await o.removeWatermarkFromImage(s,c||{});typeof s.close=="function"&&s.close();let u=await(await Ut(f)).arrayBuffer();self.postMessage({id:n,ok:!0,result:{processedBuffer:u,mimeType:"image/png",meta:f.__watermarkMeta||null}},[u])}catch(o){self.postMessage({id:n,ok:!1,error:Ct(o)})}});})();\n' : "";
  var enginePromise = null;
  var workerClient = null;
  var processingQueue = /* @__PURE__ */ new Set();
  var retryTimers = /* @__PURE__ */ new WeakMap();
  var debounce = (func, wait) => {
    let timeout;
    return (...args) => {
      clearTimeout(timeout);
      timeout = setTimeout(() => func(...args), wait);
    };
  };
  var loadImage = (src) => new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = src;
  });
  var canUseInlineWorker = () => shouldUseInlineWorker(USERSCRIPT_WORKER_CODE);
  var toError = (errorLike, fallback = "Inline worker error") => {
    if (errorLike instanceof Error) return errorLike;
    if (typeof errorLike === "string" && errorLike.length > 0) return new Error(errorLike);
    if (errorLike && typeof errorLike.message === "string" && errorLike.message.length > 0) {
      return new Error(errorLike.message);
    }
    return new Error(fallback);
  };
  var InlineWorkerClient = class {
    constructor(workerCode) {
      const blob = new Blob([workerCode], { type: "text/javascript" });
      this.workerUrl = URL.createObjectURL(blob);
      const workerScriptUrl = toWorkerScriptUrl(this.workerUrl);
      if (!workerScriptUrl) {
        URL.revokeObjectURL(this.workerUrl);
        this.workerUrl = null;
        throw new Error("Trusted Types policy unavailable for inline worker");
      }
      try {
        this.worker = new Worker(workerScriptUrl);
      } catch (error) {
        URL.revokeObjectURL(this.workerUrl);
        this.workerUrl = null;
        throw error;
      }
      this.pending = /* @__PURE__ */ new Map();
      this.requestId = 0;
      this.handleMessage = this.handleMessage.bind(this);
      this.handleError = this.handleError.bind(this);
      this.worker.addEventListener("message", this.handleMessage);
      this.worker.addEventListener("error", this.handleError);
    }
    dispose() {
      this.worker.removeEventListener("message", this.handleMessage);
      this.worker.removeEventListener("error", this.handleError);
      this.worker.terminate();
      if (this.workerUrl) {
        URL.revokeObjectURL(this.workerUrl);
        this.workerUrl = null;
      }
      const error = new Error("Inline worker disposed");
      for (const pending of this.pending.values()) {
        clearTimeout(pending.timeoutId);
        pending.reject(error);
      }
      this.pending.clear();
    }
    handleMessage(event) {
      const payload = event?.data;
      if (!payload || typeof payload.id === "undefined") return;
      const pending = this.pending.get(payload.id);
      if (!pending) return;
      this.pending.delete(payload.id);
      clearTimeout(pending.timeoutId);
      if (payload.ok) {
        pending.resolve(payload.result);
        return;
      }
      pending.reject(new Error(payload.error?.message || "Inline worker request failed"));
    }
    handleError(event) {
      const error = new Error(event?.message || "Inline worker crashed");
      for (const pending of this.pending.values()) {
        clearTimeout(pending.timeoutId);
        pending.reject(error);
      }
      this.pending.clear();
    }
    request(type, payload, transferList = [], timeoutMs = 12e4) {
      const id = ++this.requestId;
      return new Promise((resolve, reject) => {
        const timeoutId = setTimeout(() => {
          this.pending.delete(id);
          reject(new Error(`Inline worker request timed out: ${type}`));
        }, timeoutMs);
        this.pending.set(id, { resolve, reject, timeoutId });
        try {
          this.worker.postMessage({ id, type, ...payload }, transferList);
        } catch (error) {
          clearTimeout(timeoutId);
          this.pending.delete(id);
          reject(toError(error));
        }
      });
    }
    async processBlob(blob, options = {}) {
      const inputBuffer = await blob.arrayBuffer();
      const result = await this.request(
        "process-image",
        { inputBuffer, mimeType: blob.type || "image/png", options },
        [inputBuffer]
      );
      return new Blob([result.processedBuffer], { type: result.mimeType || "image/png" });
    }
  };
  var isValidGeminiImage = (img) => img.closest("generated-image,.generated-image-container") !== null;
  var findGeminiImages = () => [...document.querySelectorAll('img[src*="googleusercontent.com"]')].filter(isValidGeminiImage);
  var fetchBlob = (url) => new Promise((resolve, reject) => {
    GM_xmlhttpRequest({
      method: "GET",
      url,
      responseType: "blob",
      onload: (response) => resolve(response.response),
      onerror: reject
    });
  });
  async function getEngine() {
    if (!enginePromise) {
      enginePromise = WatermarkEngine.create().catch((error) => {
        enginePromise = null;
        throw error;
      });
    }
    return enginePromise;
  }
  function disableInlineWorker(reason) {
    if (!workerClient) return;
    console.warn("[Gemini Watermark Remover] Disable worker path:", reason);
    workerClient.dispose();
    workerClient = null;
  }
  async function processBlobWithBestPath(blob, options = {}) {
    if (workerClient) {
      try {
        return await workerClient.processBlob(blob, options);
      } catch (error) {
        console.warn("[Gemini Watermark Remover] Worker path failed, fallback to main thread:", error);
        disableInlineWorker(error);
      }
    }
    const engine = await getEngine();
    const blobUrl = URL.createObjectURL(blob);
    try {
      const img = await loadImage(blobUrl);
      const canvas = await engine.removeWatermarkFromImage(img, options);
      return await canvasToBlob(canvas);
    } finally {
      URL.revokeObjectURL(blobUrl);
    }
  }
  function clearRetryTimer(imgElement) {
    const timerId = retryTimers.get(imgElement);
    if (timerId) {
      clearTimeout(timerId);
      retryTimers.delete(imgElement);
    }
  }
  function scheduleRetry(imgElement, delayMs) {
    clearRetryTimer(imgElement);
    const timerId = setTimeout(() => {
      retryTimers.delete(imgElement);
      if (!document.contains(imgElement)) return;
      processImage(imgElement);
    }, delayMs);
    retryTimers.set(imgElement, timerId);
  }
  async function processImage(imgElement) {
    if (imgElement?.dataset?.watermarkProcessed === "true") return;
    const retryState = readRetryState(imgElement?.dataset);
    if (!shouldProcessNow(retryState)) return;
    if (processingQueue.has(imgElement)) return;
    processingQueue.add(imgElement);
    imgElement.dataset.watermarkProcessed = "processing";
    const originalSrc = imgElement.src;
    try {
      imgElement.src = "";
      const normalSizeBlob = await fetchBlob(normalizeGoogleusercontentImageUrl(originalSrc));
      const processedBlob = await processBlobWithBestPath(normalSizeBlob, { adaptiveMode: "always" });
      const previousObjectUrl = imgElement.dataset.watermarkObjectUrl;
      if (previousObjectUrl) {
        URL.revokeObjectURL(previousObjectUrl);
      }
      const objectUrl = URL.createObjectURL(processedBlob);
      imgElement.dataset.watermarkObjectUrl = objectUrl;
      imgElement.src = objectUrl;
      clearRetryTimer(imgElement);
      resetRetryState(imgElement.dataset);
      imgElement.dataset.watermarkProcessed = "true";
      console.log("[Gemini Watermark Remover] Processed image");
    } catch (error) {
      const retry = registerProcessFailure(imgElement.dataset);
      imgElement.src = originalSrc;
      if (retry.exhausted) {
        clearRetryTimer(imgElement);
        imgElement.dataset.watermarkProcessed = "failed";
        console.warn(
          `[Gemini Watermark Remover] Failed ${retry.failureCount} times, stop retrying to avoid resource leaks:`,
          error
        );
      } else {
        imgElement.dataset.watermarkProcessed = "retrying";
        scheduleRetry(imgElement, retry.delayMs);
        console.warn(
          `[Gemini Watermark Remover] Failed to process image, retry ${retry.failureCount}/${MAX_PROCESS_RETRIES} in ${retry.delayMs}ms:`,
          error
        );
      }
    } finally {
      processingQueue.delete(imgElement);
    }
  }
  var processAllImages = () => {
    const images = findGeminiImages();
    if (images.length === 0) return;
    console.log(`[Gemini Watermark Remover] Found ${images.length} images to process`);
    images.forEach(processImage);
  };
  var setupMutationObserver = () => {
    new MutationObserver(debounce(processAllImages, 100)).observe(document.body, { childList: true, subtree: true });
    console.log("[Gemini Watermark Remover] MutationObserver active");
  };
  async function processImageBlob(blob) {
    return processBlobWithBestPath(blob, { adaptiveMode: "always" });
  }
  var { fetch: origFetch } = unsafeWindow;
  unsafeWindow.fetch = async (...args) => {
    const input = args[0];
    const url = typeof input === "string" ? input : input?.url;
    if (isGeminiGeneratedAssetUrl(url)) {
      console.log("[Gemini Watermark Remover] Intercepting:", url);
      const normalizedUrl = normalizeGoogleusercontentImageUrl(url);
      if (typeof input === "string") {
        args[0] = normalizedUrl;
      } else if (typeof Request !== "undefined" && input instanceof Request) {
        args[0] = new Request(normalizedUrl, input);
      } else {
        args[0] = normalizedUrl;
      }
      const response = await origFetch(...args);
      if (!response.ok) return response;
      try {
        const processedBlob = await processImageBlob(await response.blob());
        return new Response(processedBlob, {
          status: response.status,
          statusText: response.statusText,
          headers: response.headers
        });
      } catch (error) {
        console.warn("[Gemini Watermark Remover] Processing failed:", error);
        return response;
      }
    }
    return origFetch(...args);
  };
  (async function init() {
    try {
      console.log("[Gemini Watermark Remover] Initializing...");
      if (canUseInlineWorker()) {
        try {
          workerClient = new InlineWorkerClient(USERSCRIPT_WORKER_CODE);
          console.log("[Gemini Watermark Remover] Worker acceleration enabled");
        } catch (workerError) {
          workerClient = null;
          console.warn("[Gemini Watermark Remover] Worker initialization failed, using main thread:", workerError);
        }
      }
      if (!workerClient) {
        getEngine().catch((error) => {
          console.warn("[Gemini Watermark Remover] Engine warmup failed:", error);
        });
      }
      processAllImages();
      setupMutationObserver();
      window.addEventListener("beforeunload", () => {
        disableInlineWorker("beforeunload");
      });
      console.log("[Gemini Watermark Remover] Ready");
    } catch (error) {
      console.error("[Gemini Watermark Remover] Initialization failed:", error);
    }
  })();
})();
