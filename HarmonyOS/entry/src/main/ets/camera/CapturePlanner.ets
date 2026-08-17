import { AstroCamera } from './AstroCamera';

/**
 * 拍摄模式：单张、10秒、30秒、无限时长。
 * 这里的时间是“累计曝光时间”，不是单帧快门时间。
 */
export enum CaptureMode {
  SINGLE = 0,
  TEN_SECONDS = 1,
  THIRTY_SECONDS = 2,
  INDEFINITE = 3
}

export function captureModeLabel(mode: CaptureMode): string {
  switch (mode) {
    case CaptureMode.SINGLE:
      return '单张';
    case CaptureMode.TEN_SECONDS:
      return '10秒';
    case CaptureMode.THIRTY_SECONDS:
      return '30秒';
    case CaptureMode.INDEFINITE:
      return '无限';
    default:
      return '未知';
  }
}

export function captureModeTargetMs(mode: CaptureMode): number {
  switch (mode) {
    case CaptureMode.SINGLE:
      return 0;
    case CaptureMode.TEN_SECONDS:
      return 10000;
    case CaptureMode.THIRTY_SECONDS:
      return 30000;
    case CaptureMode.INDEFINITE:
      return Number.MAX_SAFE_INTEGER;
    default:
      return 0;
  }
}

export function isIndefiniteMode(mode: CaptureMode): boolean {
  return mode === CaptureMode.INDEFINITE;
}

/** 自动测光结果：单帧曝光时长(微秒) 和 ISO。 */
export class SceneMetering {
  exposureUs: number;
  iso: number;

  constructor(exposureUs: number, iso: number) {
    this.exposureUs = exposureUs;
    this.iso = iso;
  }

  get lightBudget(): number {
    return this.exposureUs * this.iso;
  }

  static DARK_SKY_FALLBACK(): SceneMetering {
    return new SceneMetering(250000, 1600);
  }
}

export enum ExposureLimit {
  HARDWARE = 0,
  STAR_TRAILING = 1,
  SCENE_BRIGHTNESS = 2
}

export class CapturePlan {
  subExposureUs: number;
  iso: number;
  /** 无限拍摄时为 Number.MAX_SAFE_INTEGER */
  frameCount: number;
  limitedBy: ExposureLimit;
  trailLimitUs: number;
  mode: CaptureMode;

  constructor(subExposureUs: number, iso: number, frameCount: number,
              limitedBy: ExposureLimit, trailLimitUs: number, mode: CaptureMode) {
    this.subExposureUs = subExposureUs;
    this.iso = iso;
    this.frameCount = frameCount;
    this.limitedBy = limitedBy;
    this.trailLimitUs = trailLimitUs;
    this.mode = mode;
  }

  get subExposureMs(): number {
    return Math.floor(this.subExposureUs / 1000);
  }

  get plannedIntegrationMs(): number {
    if (this.frameCount === Number.MAX_SAFE_INTEGER) {
      return Number.MAX_SAFE_INTEGER;
    }
    return this.frameCount * this.subExposureMs;
  }

  static formatSeconds(us: number): string {
    const seconds = us / 1000000.0;
    if (seconds >= 1.0) {
      return `${seconds.toFixed(1)} 秒`;
    }
    return `${seconds.toFixed(2)} 秒`;
  }

  summary(): string {
    const frames = this.frameCount === Number.MAX_SAFE_INTEGER ? '无限' : `${this.frameCount}`;
    return `${frames} × ${CapturePlan.formatSeconds(this.subExposureUs)} @ ISO ${this.iso}`;
  }
}

export class CapturePlanner {
  static readonly MAX_STACK_FRAMES = 100;

  static starTrailLimitUs(camera: AstroCamera): number {
    const seconds = (35 * camera.apertureF + 30 * camera.pixelPitchUm) / camera.focalLengthMm;
    return Math.max(1, Math.floor(seconds * 1000000));
  }

  static plan(camera: AstroCamera, mode: CaptureMode, metering: SceneMetering,
              evOffset: number = 0): CapturePlan {
    const trailLimit = CapturePlanner.starTrailLimitUs(camera);
    const hardwareLimit = camera.maxExposureUs;
    let subExposure = Math.min(hardwareLimit, trailLimit);
    subExposure = Math.max(subExposure, camera.minExposureUs);

    let limitedBy = trailLimit < hardwareLimit ? ExposureLimit.STAR_TRAILING : ExposureLimit.HARDWARE;

    // 把测到的“光量”按新的快门时长重新折算 ISO。
    let requestedIso = (metering.lightBudget / subExposure) * Math.pow(2, evOffset);

    if (requestedIso < camera.minIso) {
      const shortened = Math.floor(subExposure * (requestedIso / camera.minIso));
      subExposure = Math.max(camera.minExposureUs, Math.min(shortened, hardwareLimit));
      requestedIso = camera.minIso;
      limitedBy = ExposureLimit.SCENE_BRIGHTNESS;
    }

    const iso = Math.round(requestedIso);
    const isoClamped = Math.max(camera.minIso, Math.min(iso, camera.maxIso));

    let frameCount: number;
    if (mode === CaptureMode.SINGLE) {
      frameCount = 1;
    } else if (isIndefiniteMode(mode)) {
      frameCount = Number.MAX_SAFE_INTEGER;
    } else {
      const subMs = Math.max(1, Math.floor(subExposure / 1000));
      const needed = Math.ceil(captureModeTargetMs(mode) / subMs);
      frameCount = Math.max(1, Math.min(needed, CapturePlanner.MAX_STACK_FRAMES));
    }

    return new CapturePlan(subExposure, isoClamped, frameCount, limitedBy, trailLimit, mode);
  }
}
