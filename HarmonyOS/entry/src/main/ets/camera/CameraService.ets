import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AstroCamera } from './AstroCamera';
import { CapturePlan, SceneMetering } from './CapturePlanner';
import { FrameStacker } from './FrameStacker';

const TAG = 'DeepSkyCamera';
const MAX_CAPTURE_PIXELS = 16800000;
const METER_TIMEOUT_MS = 4000;

export class CaptureCallbacks {
  onFrameStacked(framesDone: number, framesTarget: number, shiftX: number, shiftY: number): void {
  }

  onExposureConfirmed(exposureUs: number, iso: number): void {
  }

  onStopping(): void {
  }

  onCaptureComplete(jpeg: ArrayBuffer | null, frames: number, integrationMs: number): void {
  }

  onError(message: string): void {
  }
}

class CaptureBudget {
  target: number;
  warmupFrames: number;
  delivered: number = 0;
  stacked: number = 0;

  constructor(target: number, warmupFrames: number = 1) {
    this.target = target;
    this.warmupFrames = warmupFrames;
  }

  onFrameDelivered(): number {
    // 0=丢弃, 1=叠加, 2=叠加并结束
    this.delivered++;
    if (this.delivered <= this.warmupFrames) {
      return 0;
    }
    this.stacked++;
    if (this.target !== Number.MAX_SAFE_INTEGER && this.stacked >= this.target) {
      return 2;
    }
    return 1;
  }
}

export class CameraService {
  private context?: common.UIAbilityContext;
  private manager?: camera.CameraManager;
  private devices: Map<string, camera.CameraDevice> = new Map();
  private profiles: Map<string, camera.Profile> = new Map();
  private cameraInput?: camera.CameraInput;
  private session?: camera.PhotoSession;
  private previewOutput?: camera.PreviewOutput;
  private processOutput?: camera.PreviewOutput;
  private receiver?: image.ImageReceiver;
  private currentCamera?: AstroCamera;
  private stacker?: FrameStacker;
  private budget?: CaptureBudget;
  private capturing: boolean = false;
  private framesTarget: number = 0;
  private captureStartedAt: number = 0;
  private lastFrameAt: number = 0;
  private callbacks?: CaptureCallbacks;
  private lastExposureUs: number = 250000;
  private lastIso: number = 1600;
  private frameTimeoutMs: number = 10000;
  private autoStretch: boolean = true;
  private focusDistance: number = 1;
  private zoomRatio: number = 1;
  private whiteBalanceMode: number = 0;
  private whiteBalanceKelvin: number = 5000;
  private apertureValue: number = 0;
  private watchdogId: number = -1;

  async discover(context: common.UIAbilityContext): Promise<AstroCamera[]> {
    this.context = context;
    const manager = camera.getCameraManager(context);
    this.manager = manager;
    const devices = manager.getSupportedCameras();
    const result: AstroCamera[] = [];
    this.devices.clear();
    this.profiles.clear();

    for (const device of devices) {
      try {
        const modes = manager.getSupportedSceneModes(device);
        if (!modes.includes(camera.SceneMode.NORMAL_PHOTO)) {
          continue;
        }
        const cap = manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
        const yuvProfiles = cap.previewProfiles.filter((p) => p.format === camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP);
        if (yuvProfiles.length === 0) {
          continue;
        }
        const pool = yuvProfiles;
        const chosen = pool
          .filter((p) => p.size.width * p.size.height <= MAX_CAPTURE_PIXELS)
          .sort((a, b) => (b.size.width * b.size.height) - (a.size.width * a.size.height))[0] || pool[0];
        if (chosen === undefined) {
          continue;
        }
        const profile = chosen;

        const astro = new AstroCamera();
        astro.id = device.cameraId;
        astro.position = device.cameraPosition;
        astro.cameraType = device.cameraType;
        astro.focalLengthMm = device.lensFocalLength ?? 4.0;
        astro.apertureF = 1.8; // 会话打开后可再通过 Aperture 查询
        astro.previewWidth = profile.size.width;
        astro.previewHeight = profile.size.height;
        astro.sensorOrientation = device.cameraOrientation ?? 90;
        astro.supportsManual = true;
        astro.label = this.labelFor(device, astro.focalLengthMm);

        // 像素间距：传感器物理宽度 / 当前输出宽度，单位微米。
        const physical = device.sensorPhysicalSize ?? [];
        const physicalWidth = physical[0];
        if (physical.length >= 2 && profile.size.width > 0 && physicalWidth !== undefined) {
          astro.pixelPitchUm = (physicalWidth / profile.size.width) * 1000;
        }

        this.devices.set(astro.id, device);
        this.profiles.set(astro.id, profile);
        result.push(astro);
      } catch (e) {
        const err = e as BusinessError;
        hilog.warn(0x0000, TAG, 'discover camera failed: %{public}s', JSON.stringify(err));
      }
    }

    // 后置优先，手动能力优先，曝光上限高优先。
    const rear = result.filter((c) => !c.isFrontFacing());
    const front = result.filter((c) => c.isFrontFacing());
    rear.sort((a, b) => b.maxExposureUs - a.maxExposureUs);
    front.sort((a, b) => b.maxExposureUs - a.maxExposureUs);
    return rear.concat(front);
  }

  private labelFor(device: camera.CameraDevice, focalLengthMm: number): string {
    if (device.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
      return '前置';
    }
    if (device.cameraType === camera.CameraType.CAMERA_TYPE_ULTRA_WIDE || focalLengthMm < 3.0) {
      return '超广角';
    }
    if (device.cameraType === camera.CameraType.CAMERA_TYPE_TELEPHOTO || focalLengthMm > 7.0) {
      return '长焦';
    }
    return '主摄';
  }

  async open(context: common.UIAbilityContext, cameraInfo: AstroCamera,
             xcomponentSurfaceId: string, callbacks: CaptureCallbacks): Promise<void> {
    this.close();
    this.context = context;
    this.currentCamera = cameraInfo;

    const manager = camera.getCameraManager(context);
    this.manager = manager;
    const device = this.devices.get(cameraInfo.id);
    if (!device) {
      throw new Error('未找到相机设备');
    }
    const profile = this.profiles.get(cameraInfo.id);
    if (!profile) {
      throw new Error('未找到相机输出配置');
    }

    const cameraInput = manager.createCameraInput(device);
    this.cameraInput = cameraInput;
    await cameraInput.open();

    const session = manager.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession;
    this.session = session;
    session.beginConfig();
    session.addInput(cameraInput);

    // 第一路：显示预览
    const displayOutput = manager.createPreviewOutput(profile, xcomponentSurfaceId);
    this.previewOutput = displayOutput;
    session.addOutput(displayOutput);

    // 第二路：ImageReceiver 获取 NV21 帧做叠加
    const receiver = image.createImageReceiver(
      { width: profile.size.width, height: profile.size.height },
      image.ImageFormat.JPEG,
      8
    );
    this.receiver = receiver;
    const processSurfaceId = await receiver.getReceivingSurfaceId();
    const processOutput = manager.createPreviewOutput(profile, processSurfaceId);
    this.processOutput = processOutput;
    session.addOutput(processOutput);

    await session.commitConfig();
    await session.start();
    this.callbacks = callbacks;

    // 读取真实硬件能力：手动曝光范围、ISO 范围、物理光圈。
    try {
      const expRange = session.getSupportedExposureDurationRange();
      if (expRange.length >= 2) {
        cameraInfo.minExposureUs = expRange[0] ?? cameraInfo.minExposureUs;
        cameraInfo.maxExposureUs = expRange[expRange.length - 1] ?? cameraInfo.maxExposureUs;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'get exposure range failed: %{public}s', JSON.stringify(err));
    }
    try {
      const isoRange = session.getSupportedIsoRange();
      if (isoRange.length >= 2) {
        cameraInfo.minIso = isoRange[0] ?? cameraInfo.minIso;
        cameraInfo.maxIso = isoRange[isoRange.length - 1] ?? cameraInfo.maxIso;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'get iso range failed: %{public}s', JSON.stringify(err));
    }
    try {
      const aperture = session.getPhysicalAperture();
      if (aperture > 0) {
        cameraInfo.apertureF = aperture;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'get aperture failed: %{public}s', JSON.stringify(err));
    }
    try {
      const zoomRange = session.getZoomRatioRange();
      if (zoomRange.length >= 2) {
        cameraInfo.zoomMin = zoomRange[0] ?? 1;
        cameraInfo.zoomMax = zoomRange[zoomRange.length - 1] ?? 1;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'get zoom range failed: %{public}s', JSON.stringify(err));
    }
    try {
      const physicalApertures = session.getSupportedPhysicalApertures();
      const values: number[] = [];
      for (const item of physicalApertures) {
        const list = item.apertures ?? [];
        for (const value of list) {
          if (values.indexOf(value) < 0) {
            values.push(value);
          }
        }
      }
      if (values.length > 0) {
        cameraInfo.apertureValues = values.sort((a, b) => a - b);
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'get supported apertures failed: %{public}s', JSON.stringify(err));
    }
    try {
      const wbRange = session.getWhiteBalanceRange();
      if (wbRange.length >= 2) {
        cameraInfo.whiteBalanceMin = wbRange[0] ?? 2800;
        cameraInfo.whiteBalanceMax = wbRange[wbRange.length - 1] ?? 10000;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'get white balance range failed: %{public}s', JSON.stringify(err));
    }

    // 监听实际曝光/ISO（自动测光阶段会用）
    session.onExposureInfoChange((info: camera.ExposureInfo) => {
      this.lastExposureUs = info.exposureTime ?? this.lastExposureUs;
    });
    session.onIsoInfoChange((info: camera.IsoInfo) => {
      this.lastIso = info.iso ?? this.lastIso;
    });

    // 注册帧回调
    receiver.on('imageArrival', () => {
      this.onImageArrival(receiver);
    });

    hilog.info(0x0000, TAG, 'camera opened: %{public}s', cameraInfo.id);
  }

  setFocusDistance(distance: number): void {
    this.focusDistance = distance;
    if (!this.session) {
      return;
    }
    try {
      this.session.setFocusMode(camera.FocusMode.FOCUS_MODE_MANUAL);
      this.session.setFocusDistance(distance);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'set focus distance failed: %{public}s', JSON.stringify(err));
    }
  }

  setExposureBias(ev: number): void {
    if (!this.session) {
      return;
    }
    try {
      if (!this.capturing) {
        this.session.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_CONTINUOUS_AUTO);
      }
      this.session.setExposureBias(ev);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'set exposure bias failed: %{public}s', JSON.stringify(err));
    }
  }

  setZoomRatio(ratio: number): void {
    this.zoomRatio = ratio;
    if (!this.session) {
      return;
    }
    try {
      this.session.setZoomRatio(ratio);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'set zoom ratio failed: %{public}s', JSON.stringify(err));
    }
  }

  setWhiteBalanceMode(mode: number): void {
    this.whiteBalanceMode = mode;
    if (!this.session) {
      return;
    }
    try {
      this.session.setWhiteBalanceMode(mode as camera.WhiteBalanceMode);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'set white balance mode failed: %{public}s', JSON.stringify(err));
    }
  }

  setManualWhiteBalance(kelvin: number): void {
    this.whiteBalanceKelvin = kelvin;
    this.whiteBalanceMode = 5;
    if (!this.session) {
      return;
    }
    try {
      this.session.setWhiteBalanceMode(camera.WhiteBalanceMode.MANUAL);
      this.session.setWhiteBalance(kelvin);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'set manual white balance failed: %{public}s', JSON.stringify(err));
    }
  }

  setAperture(aperture: number): void {
    this.apertureValue = aperture;
    if (!this.session || aperture <= 0) {
      return;
    }
    try {
      this.session.setPhysicalAperture(aperture);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'set aperture failed: %{public}s', JSON.stringify(err));
    }
  }

  async meter(): Promise<SceneMetering> {
    if (!this.session) {
      return SceneMetering.DARK_SKY_FALLBACK();
    }
    // 先切回自动曝光，等待几帧后读取回调里的实际值。
    try {
      this.session.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_CONTINUOUS_AUTO);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'set auto exposure failed: %{public}s', JSON.stringify(err));
    }
    await new Promise<void>((resolve) => setTimeout(resolve, 600));
    const exposure = this.lastExposureUs > 0 ? this.lastExposureUs : 250000;
    const iso = this.lastIso > 0 ? this.lastIso : 1600;
    return new SceneMetering(exposure, iso);
  }

  async startCapture(plan: CapturePlan, alignFrames: boolean, autoStretch: boolean): Promise<void> {
    if (!this.session || !this.currentCamera || !this.receiver) {
      throw new Error('相机尚未准备好');
    }
    const cameraInfo = this.currentCamera;
    this.stacker = new FrameStacker(cameraInfo.previewWidth, cameraInfo.previewHeight, alignFrames, 32);
    this.budget = new CaptureBudget(plan.frameCount, 1);
    this.framesTarget = plan.frameCount;
    this.captureStartedAt = Date.now();
    this.lastFrameAt = this.captureStartedAt;
    this.frameTimeoutMs = Math.max(8000, plan.subExposureMs * 4);
    this.autoStretch = autoStretch;
    this.capturing = true;

    // 手动曝光、手动 ISO、手动对焦、关闭防抖（如支持）
    try {
      this.session.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_MANUAL);
      this.session.setExposureDuration(plan.subExposureUs);
      this.session.setIso(plan.iso);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'manual exposure config failed: %{public}s', JSON.stringify(err));
    }
    try {
      this.session.setFocusMode(camera.FocusMode.FOCUS_MODE_MANUAL);
      this.session.setFocusDistance(this.focusDistance);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'manual focus config failed: %{public}s', JSON.stringify(err));
    }
    // 三脚架拍摄时应关闭光学防抖，避免防抖组件在长曝光中引入位移。
    try {
      this.session.setOISMode(camera.OISMode.OFF);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'ois off failed: %{public}s', JSON.stringify(err));
    }
    // 星空拍摄不需要闪光灯。
    try {
      this.session.setFlashMode(camera.FlashMode.FLASH_MODE_CLOSE);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'flash off failed: %{public}s', JSON.stringify(err));
    }
    // 把预览时调好的焦段/白平衡/光圈也应用到拍摄帧。
    try {
      this.session.setZoomRatio(this.zoomRatio);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'apply zoom failed: %{public}s', JSON.stringify(err));
    }
    try {
      if (this.whiteBalanceMode === 5) {
        this.session.setWhiteBalanceMode(camera.WhiteBalanceMode.MANUAL);
        this.session.setWhiteBalance(this.whiteBalanceKelvin);
      } else {
        this.session.setWhiteBalanceMode(this.whiteBalanceMode as camera.WhiteBalanceMode);
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'apply white balance failed: %{public}s', JSON.stringify(err));
    }
    if (this.apertureValue > 0) {
      try {
        this.session.setPhysicalAperture(this.apertureValue);
      } catch (e) {
        const err = e as BusinessError;
        hilog.warn(0x0000, TAG, 'apply aperture failed: %{public}s', JSON.stringify(err));
      }
    }
    this.startWatchdog();
    hilog.info(0x0000, TAG, 'capture start: target=%{public}d sub=%{public}d iso=%{public}d',
      plan.frameCount, plan.subExposureUs, plan.iso);
  }

  stopCapture(reason: string = 'user'): void {
    if (!this.capturing) {
      return;
    }
    this.capturing = false;
    this.stopWatchdog();
    // 拍完后恢复自动曝光，让预览回到明亮可调的状态。
    try {
      this.session?.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_CONTINUOUS_AUTO);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'restore auto exposure failed: %{public}s', JSON.stringify(err));
    }
    const stacker = this.stacker;
    const elapsed = Date.now() - this.captureStartedAt;
    hilog.info(0x0000, TAG, 'stopCapture(%{public}s): %{public}d frames', reason, stacker?.frameCount ?? 0);
    this.callbacks?.onStopping();

    if (!stacker || stacker.frameCount === 0) {
      this.callbacks?.onCaptureComplete(null, 0, elapsed);
      return;
    }
    const nv21 = stacker.averageToNv21(this.autoStretch);
    if (!nv21) {
      this.callbacks?.onCaptureComplete(null, 0, elapsed);
      return;
    }
    this.encodeJpeg(nv21, stacker.outputWidth, stacker.outputHeight).then((jpeg) => {
      this.callbacks?.onCaptureComplete(jpeg, stacker.frameCount, elapsed);
    }).catch((e: BusinessError) => {
      hilog.error(0x0000, TAG, 'encode jpeg failed: %{public}s', JSON.stringify(e));
      this.callbacks?.onCaptureComplete(null, stacker.frameCount, elapsed);
    });
    this.stacker = undefined;
  }

  close(): void {
    this.stopWatchdog();
    this.capturing = false;
    this.callbacks = undefined;
    try {
      const p = this.session?.stop();
      if (p) {
        p.catch((e: BusinessError) => {
          hilog.warn(0x0000, TAG, 'session stop failed: %{public}s', JSON.stringify(e));
        });
      }
    } catch (e) {
    }
    try {
      const p = this.session?.release();
      if (p) {
        p.catch((e: BusinessError) => {
          hilog.warn(0x0000, TAG, 'session release failed: %{public}s', JSON.stringify(e));
        });
      }
    } catch (e) {
    }
    try {
      const p = this.previewOutput?.release();
      if (p) {
        p.catch((e: BusinessError) => {
          hilog.warn(0x0000, TAG, 'previewOutput release failed: %{public}s', JSON.stringify(e));
        });
      }
    } catch (e) {
    }
    try {
      const p = this.processOutput?.release();
      if (p) {
        p.catch((e: BusinessError) => {
          hilog.warn(0x0000, TAG, 'processOutput release failed: %{public}s', JSON.stringify(e));
        });
      }
    } catch (e) {
    }
    try {
      const p = this.cameraInput?.close();
      if (p) {
        p.catch((e: BusinessError) => {
          hilog.warn(0x0000, TAG, 'cameraInput close failed: %{public}s', JSON.stringify(e));
        });
      }
    } catch (e) {
    }
    try {
      this.receiver?.release();
    } catch (e) {
    }
    this.session = undefined;
    this.previewOutput = undefined;
    this.processOutput = undefined;
    this.cameraInput = undefined;
    this.receiver = undefined;
    this.stacker = undefined;
    this.currentCamera = undefined;
  }

  private onImageArrival(receiver: image.ImageReceiver): void {
    if (!this.capturing) {
      // 非拍摄状态也要把帧读走并释放，否则缓冲区会满。
      receiver.readNextImage((err: BusinessError, nextImage: image.Image) => {
        if (!err && nextImage) {
          const p = nextImage.release();
          if (p) {
            p.catch((e: BusinessError) => {
              hilog.warn(0x0000, TAG, 'image release failed: %{public}s', JSON.stringify(e));
            });
          }
        }
      });
      return;
    }
    receiver.readNextImage((err: BusinessError, nextImage: image.Image) => {
      if (err || !nextImage) {
        return;
      }
      nextImage.getComponent(image.ComponentType.JPEG, async (compErr: BusinessError, component: image.Component) => {
        if (compErr || !component || !component.byteBuffer) {
          await nextImage.release();
          return;
        }
        try {
          this.handleFrame(component.byteBuffer, component.rowStride);
        } catch (e) {
          const error = e as Error;
          hilog.error(0x0000, TAG, 'handleFrame failed: %{public}s', error.message);
          this.callbacks?.onError(error.message);
          this.capturing = false;
          this.stopWatchdog();
        } finally {
          await nextImage.release();
        }
      });
    });
  }

  private handleFrame(buffer: ArrayBuffer, stride: number): void {
    const stacker = this.stacker;
    const budget = this.budget;
    if (!stacker || !budget) {
      return;
    }
    this.lastFrameAt = Date.now();
    const action = budget.onFrameDelivered();
    if (action === 0) {
      return;
    }
    stacker.addNv21(buffer, stride);
    const done = stacker.frameCount;
    this.callbacks?.onFrameStacked(done, this.framesTarget, stacker.lastShiftX, stacker.lastShiftY);
    if (action === 2) {
      this.stopCapture('reached target');
    }
  }

  private startWatchdog(): void {
    this.stopWatchdog();
    const loop = () => {
      if (!this.capturing) {
        return;
      }
      const silence = Date.now() - this.lastFrameAt;
      if (silence > this.frameTimeoutMs) {
        hilog.warn(0x0000, TAG, 'no frame for %{public}d ms, ending capture', silence);
        this.stopCapture('stalled');
      } else {
        this.watchdogId = setTimeout(loop, 2000);
      }
    };
    this.watchdogId = setTimeout(loop, 2000);
  }

  private stopWatchdog(): void {
    if (this.watchdogId >= 0) {
      clearTimeout(this.watchdogId);
      this.watchdogId = -1;
    }
  }

  private async encodeJpeg(nv21: ArrayBuffer, width: number, height: number): Promise<ArrayBuffer> {
    const pixelMap = await image.createPixelMap(nv21, {
      size: { width: width, height: height },
      srcPixelFormat: image.PixelMapFormat.NV21
    });
    const packer = image.createImagePacker();
    const jpeg = await packer.packing(pixelMap, { format: 'image/jpeg', quality: 95 });
    await pixelMap.release();
    return jpeg;
  }
}
