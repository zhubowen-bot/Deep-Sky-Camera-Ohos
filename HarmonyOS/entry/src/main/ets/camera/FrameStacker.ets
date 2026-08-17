/**
 * 多帧叠加器：把多张短曝光 YUV(NV21) 帧累加成一张深空照片。
 * 逻辑与安卓版 FrameStacker 对齐，使用 32 位累加器保留精度。
 */
export class FrameStacker {
  width: number;
  height: number;
  private alignFrames: boolean;
  private margin: number;
  private yAcc: Int32Array;
  private uAcc: Int32Array;
  private vAcc: Int32Array;
  private yScratch: Uint8Array;
  private uScratch: Uint8Array;
  private vScratch: Uint8Array;
  frameCount: number = 0;
  lastShiftX: number = 0;
  lastShiftY: number = 0;
  private referenceX: number = 0;
  private referenceY: number = 0;
  private haveReference: boolean = false;

  constructor(width: number, height: number, alignFrames: boolean = true, margin: number = 0) {
    if (width <= 0 || height <= 0) {
      throw new Error('Frame size must be positive');
    }
    if (width % 2 !== 0 || height % 2 !== 0) {
      throw new Error('4:2:0 chroma needs even dimensions');
    }
    if (margin < 0 || margin % 2 !== 0 || width - 2 * margin <= 0 || height - 2 * margin <= 0) {
      throw new Error('Invalid margin');
    }
    this.width = width;
    this.height = height;
    this.alignFrames = alignFrames;
    this.margin = margin;
    this.yAcc = new Int32Array(width * height);
    this.uAcc = new Int32Array(width * height / 4);
    this.vAcc = new Int32Array(width * height / 4);
    this.yScratch = new Uint8Array(width * height);
    this.uScratch = new Uint8Array(width * height / 4);
    this.vScratch = new Uint8Array(width * height / 4);
  }

  get outputWidth(): number {
    return this.width - 2 * this.margin;
  }

  get outputHeight(): number {
    return this.height - 2 * this.margin;
  }

  /**
   * 将一帧 NV21 数据加入叠加。
   * @param buffer 原始 NV21 数据
   * @param stride Y 平面行距，通常大于 width
   */
  addNv21(buffer: ArrayBuffer, stride: number): void {
    const bytes = new Uint8Array(buffer);
    this.extractY(bytes, stride);
    this.extractChroma(bytes, stride);

    let shiftX = 0;
    let shiftY = 0;
    if (this.alignFrames) {
      const centroid = this.starCentroid(this.yScratch);
      if (centroid != null) {
        const cx = centroid[0];
        const cy = centroid[1];
        if (cx !== undefined && cy !== undefined) {
          if (!this.haveReference) {
            this.referenceX = cx;
            this.referenceY = cy;
            this.haveReference = true;
          } else {
            shiftX = Math.round((cx - this.referenceX) * 8);
            shiftY = Math.round((cy - this.referenceY) * 8);
            if (Math.abs(shiftX) > 256 || Math.abs(shiftY) > 256) {
              shiftX = 0;
              shiftY = 0;
            }
          }
        }
      }
    }
    this.lastShiftX = shiftX;
    this.lastShiftY = shiftY;

    this.accumulate(this.yScratch, this.yAcc, this.width, this.height, shiftX, shiftY);
    this.accumulate(this.uScratch, this.uAcc, this.width / 2, this.height / 2, Math.floor(shiftX / 2), Math.floor(shiftY / 2));
    this.accumulate(this.vScratch, this.vAcc, this.width / 2, this.height / 2, Math.floor(shiftX / 2), Math.floor(shiftY / 2));
    this.frameCount++;
  }

  private extractY(bytes: Uint8Array, stride: number): void {
    const w = this.width;
    const h = this.height;
    for (let y = 0; y < h; y++) {
      const srcRow = y * stride;
      const dstRow = y * w;
      for (let x = 0; x < w; x++) {
        this.yScratch[dstRow + x] = bytes[srcRow + x];
      }
    }
  }

  private extractChroma(bytes: Uint8Array, stride: number): void {
    const cw = this.width / 2;
    const ch = this.height / 2;
    const chromaBase = stride * this.height;
    for (let y = 0; y < ch; y++) {
      const srcRow = chromaBase + y * stride;
      const dstRow = y * cw;
      for (let x = 0; x < cw; x++) {
        // NV21: V 在前，U 在后
        this.vScratch[dstRow + x] = bytes[srcRow + x * 2];
        this.uScratch[dstRow + x] = bytes[srcRow + x * 2 + 1];
      }
    }
  }

  private accumulate(src: Uint8Array, dst: Int32Array, planeWidth: number, planeHeight: number,
                     shiftX: number, shiftY: number): void {
    for (let y = 0; y < planeHeight; y++) {
      const sourceRow = Math.max(0, Math.min(planeHeight - 1, y + shiftY)) * planeWidth;
      const targetRow = y * planeWidth;
      if (shiftX === 0) {
        for (let x = 0; x < planeWidth; x++) {
          dst[targetRow + x] += src[sourceRow + x];
        }
      } else {
        for (let x = 0; x < planeWidth; x++) {
          const sourceX = Math.max(0, Math.min(planeWidth - 1, x + shiftX));
          dst[targetRow + x] += src[sourceRow + sourceX];
        }
      }
    }
  }

  averageToNv21(autoStretch: boolean): ArrayBuffer | null {
    if (this.frameCount === 0) {
      return null;
    }
    const ow = this.outputWidth;
    const oh = this.outputHeight;
    const ocw = Math.floor(ow / 2);
    const och = Math.floor(oh / 2);
    const lumaSize = ow * oh;
    const nv21 = new Uint8Array(lumaSize + ocw * och * 2);

    for (let y = 0; y < oh; y++) {
      const sourceRow = (y + this.margin) * this.width + this.margin;
      const targetRow = y * ow;
      for (let x = 0; x < ow; x++) {
        nv21[targetRow + x] = Math.max(0, Math.min(255, Math.floor(this.yAcc[sourceRow + x] / this.frameCount)));
      }
    }

    if (autoStretch) {
      this.stretchLuma(nv21, lumaSize);
    }

    const chromaMargin = Math.floor(this.margin / 2);
    let out = lumaSize;
    for (let y = 0; y < och; y++) {
      const sourceRow = (y + chromaMargin) * Math.floor(this.width / 2) + chromaMargin;
      for (let x = 0; x < ocw; x++) {
        nv21[out++] = Math.max(0, Math.min(255, Math.floor(this.vAcc[sourceRow + x] / this.frameCount)));
        nv21[out++] = Math.max(0, Math.min(255, Math.floor(this.uAcc[sourceRow + x] / this.frameCount)));
      }
    }

    return nv21.buffer;
  }

  private stretchLuma(buffer: Uint8Array, lumaSize: number): void {
    const histogram = new Int32Array(256);
    for (let i = 0; i < lumaSize; i++) {
      histogram[buffer[i]]++;
    }
    const blackPoint = this.percentile(histogram, lumaSize, 0.001);
    const whitePoint = this.percentile(histogram, lumaSize, 0.9995);
    if (whitePoint <= blackPoint) {
      return;
    }
    const scale = Math.min(245 / (whitePoint - blackPoint), 8);
    const lut = new Uint8Array(256);
    for (let value = 0; value <= 255; value++) {
      const linear = Math.max(0, Math.min(255, (value - blackPoint) * scale));
      const lifted = Math.round(255 * Math.pow(linear / 255, 0.80));
      lut[value] = Math.max(0, Math.min(255, lifted));
    }
    for (let i = 0; i < lumaSize; i++) {
      buffer[i] = lut[buffer[i]];
    }
  }

  private percentile(histogram: Int32Array, total: number, fraction: number): number {
    const target = Math.max(0, Math.min(total, Math.floor(total * fraction)));
    let running = 0;
    for (let value = 0; value <= 255; value++) {
      running += histogram[value];
      if (running >= target) {
        return value;
      }
    }
    return 255;
  }

  private starCentroid(luma: Uint8Array): number[] | null {
    const down = 8;
    const sw = Math.floor(this.width / down);
    const sh = Math.floor(this.height / down);
    if (sw < 8 || sh < 8) {
      return null;
    }
    const samples = sw * sh;
    const small = new Int32Array(samples);
    let sum = 0;
    let sumSquares = 0;
    let index = 0;
    for (let y = 0; y < sh; y++) {
      const row = y * down * this.width;
      for (let x = 0; x < sw; x++) {
        const value = luma[row + x * down];
        small[index++] = value;
        sum += value;
        sumSquares += value * value;
      }
    }
    const mean = sum / samples;
    const variance = Math.max(0, sumSquares / samples - mean * mean);
    const deviation = Math.sqrt(variance);
    if (deviation < 0.5) {
      return null;
    }
    const threshold = mean + 3 * deviation;
    let weightTotal = 0;
    let weightedX = 0;
    let weightedY = 0;
    let bright = 0;
    index = 0;
    for (let y = 0; y < sh; y++) {
      for (let x = 0; x < sw; x++) {
        const value = small[index++];
        if (value > threshold) {
          const weight = value - threshold;
          weightTotal += weight;
          weightedX += weight * x;
          weightedY += weight * y;
          bright++;
        }
      }
    }
    if (bright < 6 || weightTotal <= 0) {
      return null;
    }
    return [weightedX / weightTotal, weightedY / weightTotal];
  }
}
