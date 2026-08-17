import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';
import { CameraService, CaptureCallbacks } from '../camera/CameraService';
import { AstroCamera } from '../camera/AstroCamera';
import {
  CaptureMode,
  CapturePlan,
  CapturePlanner,
  ExposureLimit,
  SceneMetering,
  captureModeLabel
} from '../camera/CapturePlanner';
import { Settings, SettingsStore } from '../model/SettingsStore';

const TAG = 'DeepSkyIndex';

@Entry
@Component
struct Index {
  @State hasPermission: boolean = false;
  @State cameras: AstroCamera[] = [];
  @State selectedCamera: AstroCamera | null = null;
  @State mode: CaptureMode = CaptureMode.TEN_SECONDS;
  @State plan: CapturePlan | null = null;
  @State phase: string = 'idle'; // idle | opening | ready | metering | capturing | saving
  @State framesDone: number = 0;
  @State framesTarget: number = 0;
  @State elapsedMs: number = 0;
  @State countdown: number = -1;
  @State message: string = '';
  @State showTuning: boolean = false;
  @State focusValue: number = 1;
  @State evValue: number = 0;
  @State timerSeconds: number = 3;
  @State zoomValue: number = 1;
  @State whiteBalanceMode: number = 0;
  @State whiteBalanceKelvin: number = 5000;
  @State apertureValue: number = 0;
  @State alignFrames: boolean = true;
  @State autoStretch: boolean = true;
  @State lastSavedName: string = '';

  private xComponentController: XComponentController = new XComponentController();
  private service: CameraService = new CameraService();
  private settingsStore: SettingsStore | null = null;
  private surfaceId: string = '';
  private metering: SceneMetering = SceneMetering.DARK_SKY_FALLBACK();
  private timerJob: number = -1;
  private countdownJob: number = -1;
  private cameraInitialized: boolean = false;

  aboutToAppear(): void {
    this.init();
  }

  private async init(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.settingsStore = new SettingsStore(ctx);
    await this.settingsStore.init();
    const settings = await this.settingsStore.load();
    this.alignFrames = settings.alignFrames;
    this.autoStretch = settings.autoStretch;
    this.evValue = settings.evOffset;
    this.focusValue = settings.focusDistance;
    this.timerSeconds = settings.timerSeconds;
    this.zoomValue = settings.zoomRatio;
    this.whiteBalanceMode = settings.whiteBalanceMode;
    this.whiteBalanceKelvin = settings.whiteBalanceKelvin;
    this.apertureValue = settings.apertureValue;
    await this.requestPermission();
  }

  private async requestPermission(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const result = await atManager.requestPermissionsFromUser(ctx, ['ohos.permission.CAMERA']);
      const granted = result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      this.hasPermission = granted;
      if (granted) {
        await this.discoverCameras();
      }
    } catch (e) {
      const err = e as BusinessError;
      this.message = `申请相机权限失败：${err.message}`;
    }
  }

  private async discoverCameras(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      const cameras = await this.service.discover(ctx);
      this.cameras = cameras;
      if (cameras.length === 0) {
        this.message = '未找到可用的相机';
        return;
      }
      const remembered = this.settingsStore ? (await this.settingsStore.load()).cameraId : '';
      const selected = cameras.find((c) => c.id === remembered) || cameras.find((c) => !c.isFrontFacing()) || cameras[0];
      if (selected === undefined) {
        this.message = '未找到可用的相机';
        return;
      }
      this.selectedCamera = selected;
      this.replan();
      if (this.surfaceId !== '' && !this.cameraInitialized) {
        await this.initCamera();
      }
    } catch (e) {
      const err = e as BusinessError;
      this.message = `读取相机失败：${err.message}`;
    }
  }

  aboutToDisappear(): void {
    this.stopCountdown();
    this.stopElapsedTimer();
    this.service.close();
  }

  onPageHide(): void {
    this.stopCountdown();
    this.stopElapsedTimer();
    this.service.close();
    this.cameraInitialized = false;
    if (this.phase === 'capturing' || this.phase === 'metering' || this.phase === 'opening') {
      this.phase = 'ready';
    }
  }

  onPageShow(): void {
    this.refreshSettings();
  }

  private async refreshSettings(): Promise<void> {
    if (this.settingsStore) {
      const s = await this.settingsStore.load();
      this.alignFrames = s.alignFrames;
      this.autoStretch = s.autoStretch;
      this.evValue = s.evOffset;
      this.timerSeconds = s.timerSeconds;
      this.focusValue = s.focusDistance;
      this.zoomValue = s.zoomRatio;
      this.whiteBalanceMode = s.whiteBalanceMode;
      this.whiteBalanceKelvin = s.whiteBalanceKelvin;
      this.apertureValue = s.apertureValue;
      this.replan();
    }
    if (this.hasPermission && this.selectedCamera && this.surfaceId !== '' && !this.cameraInitialized) {
      await this.initCamera();
    }
  }

  private onXComponentLoad(): void {
    this.surfaceId = this.xComponentController.getXComponentSurfaceId();
    this.initCamera();
  }

  private async initCamera(): Promise<void> {
    const camera = this.selectedCamera;
    if (this.cameraInitialized || !this.hasPermission || !camera || this.surfaceId === '') {
      return;
    }
    this.cameraInitialized = true;
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      this.xComponentController.setXComponentSurfaceRect({
        surfaceWidth: camera.previewWidth,
        surfaceHeight: camera.previewHeight
      });
      this.xComponentController.setXComponentSurfaceRotation({ lock: true });
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, 'set XComponent surface rect failed: %{public}s', JSON.stringify(err));
    }
    this.phase = 'opening';
    try {
      await this.service.open(ctx, camera, this.surfaceId, new IndexCaptureCallbacks(this));
      if (this.zoomValue < camera.zoomMin || this.zoomValue > camera.zoomMax) {
        this.zoomValue = 1;
      }
      if (camera.apertureValues.length > 0 && camera.apertureValues.indexOf(this.apertureValue) < 0) {
        this.apertureValue = 0;
      }
      this.service.setFocusDistance(this.focusValue);
      this.service.setExposureBias(this.evValue);
      this.service.setZoomRatio(this.zoomValue);
      this.service.setWhiteBalanceMode(this.whiteBalanceMode);
      if (this.whiteBalanceMode === 5) {
        this.service.setManualWhiteBalance(this.whiteBalanceKelvin);
      }
      if (this.apertureValue > 0) {
        this.service.setAperture(this.apertureValue);
      }
      this.phase = 'metering';
      this.metering = await this.service.meter();
      this.phase = 'ready';
      this.replan();
    } catch (e) {
      const err = e as BusinessError;
      this.phase = 'ready';
      this.cameraInitialized = false;
      this.message = `打开相机失败：${err.message}`;
    }
  }

  private replan(): void {
    const camera = this.selectedCamera;
    if (!camera) {
      return;
    }
    this.plan = CapturePlanner.plan(camera, this.mode, this.metering, this.evValue);
  }

  selectCamera(camera: AstroCamera): void {
    if (this.phase === 'capturing' || this.countdown >= 0 ||
      this.phase === 'opening' || this.phase === 'metering' || this.phase === 'saving') {
      return;
    }
    this.selectedCamera = camera;
    this.cameraInitialized = false;
    this.service.close();
    if (this.settingsStore) {
      const s = new Settings();
      s.alignFrames = this.alignFrames;
      s.autoStretch = this.autoStretch;
      s.evOffset = this.evValue;
      s.cameraId = camera.id;
      s.focusDistance = this.focusValue;
      s.timerSeconds = this.timerSeconds;
      s.zoomRatio = this.zoomValue;
      s.whiteBalanceMode = this.whiteBalanceMode;
      s.whiteBalanceKelvin = this.whiteBalanceKelvin;
      s.apertureValue = this.apertureValue;
      this.settingsStore.save(s);
    }
    this.initCamera();
  }

  selectMode(mode: CaptureMode): void {
    if (this.phase === 'capturing' || this.countdown >= 0 ||
      this.phase === 'opening' || this.phase === 'metering' || this.phase === 'saving') {
      return;
    }
    this.mode = mode;
    this.replan();
  }

  onShutter(): void {
    if (this.phase === 'capturing') {
      this.service.stopCapture();
      return;
    }
    if (this.countdown >= 0) {
      this.stopCountdown();
      return;
    }
    if (this.phase === 'metering' || this.phase === 'saving' || this.phase === 'opening') {
      return;
    }
    const camera = this.selectedCamera;
    const plan = this.plan;
    if (!camera || !plan) {
      return;
    }
    this.startCountdown(plan);
  }

  private startCountdown(plan: CapturePlan): void {
    this.message = '';
    let remaining = this.timerSeconds;
    if (remaining <= 0) {
      this.beginCapture(plan);
      return;
    }
    this.countdown = remaining;
    this.countdownJob = setInterval(() => {
      remaining--;
      if (remaining <= 0) {
        this.stopCountdown();
        this.beginCapture(plan);
      } else {
        this.countdown = remaining;
      }
    }, 1000);
  }

  private stopCountdown(): void {
    if (this.countdownJob >= 0) {
      clearInterval(this.countdownJob);
      this.countdownJob = -1;
    }
    this.countdown = -1;
  }

  private async beginCapture(plan: CapturePlan): Promise<void> {
    this.phase = 'metering';
    try {
      this.metering = await this.service.meter();
    } catch (e) {
      const err = e as BusinessError;
      this.phase = 'ready';
      this.message = `测光失败：${err.message}`;
      return;
    }
    this.replan();
    const finalPlan = this.plan || plan;
    this.framesDone = 0;
    this.framesTarget = finalPlan.frameCount === Number.MAX_SAFE_INTEGER ? 0 : finalPlan.frameCount;
    this.elapsedMs = 0;
    this.lastSavedName = '';
    this.phase = 'capturing';
    this.startElapsedTimer();
    try {
      await this.service.startCapture(finalPlan, this.alignFrames, this.autoStretch);
    } catch (e) {
      const err = e as BusinessError;
      this.phase = 'ready';
      this.message = `开始拍摄失败：${err.message}`;
    }
  }

  private startElapsedTimer(): void {
    this.stopElapsedTimer();
    const start = Date.now();
    this.timerJob = setInterval(() => {
      if (this.phase === 'capturing') {
        this.elapsedMs = Date.now() - start;
      }
    }, 200);
  }

  stopElapsedTimer(): void {
    if (this.timerJob >= 0) {
      clearInterval(this.timerJob);
      this.timerJob = -1;
    }
  }

  async saveJpeg(jpeg: ArrayBuffer, frames: number, integrationMs: number): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    let srcFile: fileIo.File | null = null;
    let desFile: fileIo.File | null = null;
    try {
      const srcPath = `${ctx.filesDir}/deepsky_${Date.now()}.jpg`;
      srcFile = fileIo.openSync(srcPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(srcFile.fd, jpeg);
      fileIo.closeSync(srcFile);
      srcFile = null;

      const helper = photoAccessHelper.getPhotoAccessHelper(ctx);
      const uris = await helper.showAssetsCreationDialog([srcPath], [{
        title: `深空_${frames}帧`,
        fileNameExtension: 'jpg',
        photoType: photoAccessHelper.PhotoType.IMAGE,
        subtype: photoAccessHelper.PhotoSubtype.DEFAULT
      }]);
      const uri = uris[0];
      if (uri === undefined) {
        this.message = '已取消保存';
        return;
      }

      // showAssetsCreationDialog 只返回目标 URI，必须手动把源文件写入目标 URI。
      srcFile = await fileIo.open(srcPath, fileIo.OpenMode.READ_ONLY);
      desFile = await fileIo.open(uri, fileIo.OpenMode.WRITE_ONLY);
      await fileIo.copyFile(srcFile.fd, desFile.fd);
      this.lastSavedName = uri;
      this.message = `已保存：${frames} 帧，累计 ${(integrationMs / 1000).toFixed(1)} 秒`;
    } catch (e) {
      const err = e as BusinessError;
      this.message = `保存照片失败：${err.message}`;
    } finally {
      if (srcFile) {
        try {
          fileIo.closeSync(srcFile);
        } catch (e) {
        }
      }
      if (desFile) {
        try {
          fileIo.closeSync(desFile);
        } catch (e) {
        }
      }
    }
  }

  onFocusChange(value: number): void {
    this.focusValue = value;
    this.service.setFocusDistance(value);
    this.saveSettings();
  }

  onEvChange(value: number): void {
    this.evValue = value;
    this.service.setExposureBias(value);
    this.replan();
    this.saveSettings();
  }

  onTimerChange(): void {
    if (this.phase === 'capturing' || this.countdown >= 0 ||
      this.phase === 'opening' || this.phase === 'metering' || this.phase === 'saving') {
      return;
    }
    this.timerSeconds = this.timerSeconds === 0 ? 3 : (this.timerSeconds === 3 ? 10 : 0);
    this.saveSettings();
  }

  private saveSettings(): void {
    if (!this.settingsStore) {
      return;
    }
    const s = new Settings();
    s.alignFrames = this.alignFrames;
    s.autoStretch = this.autoStretch;
    s.evOffset = this.evValue;
    s.cameraId = this.selectedCamera?.id || '';
    s.focusDistance = this.focusValue;
    s.timerSeconds = this.timerSeconds;
    s.zoomRatio = this.zoomValue;
    s.whiteBalanceMode = this.whiteBalanceMode;
    s.whiteBalanceKelvin = this.whiteBalanceKelvin;
    s.apertureValue = this.apertureValue;
    this.settingsStore.save(s);
  }

  applyAstroPreset(): void {
    this.onZoomChange(1);
    this.onFocusChange(1);
    this.onEvChange(0);
    this.onWhiteBalanceModeChange(4);
    const apertures = this.selectedCamera?.apertureValues ?? [];
    if (apertures.length > 0) {
      let wide = apertures[0] ?? 1.8;
      for (const value of apertures) {
        if (value < wide) {
          wide = value;
        }
      }
      this.onApertureChange(wide);
    }
    this.message = '已应用星空推荐参数：广角、无限远对焦、日光白平衡';
  }

  onZoomChange(value: number): void {
    this.zoomValue = value;
    this.service.setZoomRatio(value);
    this.saveSettings();
  }

  onWhiteBalanceModeChange(mode: number): void {
    this.whiteBalanceMode = mode;
    this.service.setWhiteBalanceMode(mode);
    if (mode === 5) {
      this.service.setManualWhiteBalance(this.whiteBalanceKelvin);
    }
    this.saveSettings();
  }

  onWhiteBalanceKelvinChange(value: number): void {
    this.whiteBalanceKelvin = value;
    this.whiteBalanceMode = 5;
    this.service.setManualWhiteBalance(value);
    this.saveSettings();
  }

  onApertureChange(value: number): void {
    this.apertureValue = value;
    if (value > 0) {
      this.service.setAperture(value);
    }
    this.saveSettings();
  }

  openSettings(): void {
    router.pushUrl({ url: 'pages/Settings' });
  }

  whiteBalanceLabel(mode: number): string {
    switch (mode) {
      case 0:
        return '自动';
      case 1:
        return '阴天';
      case 2:
        return '白炽';
      case 3:
        return '荧光';
      case 4:
        return '日光';
      case 5:
        return '手动';
      case 6:
        return '锁定';
      default:
        return '自动';
    }
  }

  formatElapsed(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const mm = Math.floor(totalSeconds / 60);
    const ss = totalSeconds % 60;
    return `${mm}:${ss.toString().padStart(2, '0')}`;
  }

  planReadout(plan: CapturePlan | null): string {
    if (!plan) {
      return '正在读取天空…';
    }
    const frames = plan.frameCount === Number.MAX_SAFE_INTEGER ? '无限' : `${plan.frameCount}`;
    const limitText = plan.limitedBy === ExposureLimit.SCENE_BRIGHTNESS ? '（场景过亮，已缩短单帧）' :
      (plan.limitedBy === ExposureLimit.STAR_TRAILING ? '（已按星轨限制）' : '（硬件最长单帧）');
    return `${CapturePlan.formatSeconds(plan.subExposureUs)} · ISO ${plan.iso} · ${frames}帧 ${limitText}`;
  }

  build() {
    Column() {
      if (!this.hasPermission) {
        Column({ space: 16 }) {
          Text('需要相机权限')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F3F4F7')
          Text('深空相机只会在应用使用期间调用相机拍摄夜空照片，不会上传任何数据。')
            .fontSize(14)
            .fontColor('#8B909B')
            .textAlign(TextAlign.Center)
            .padding({ left: 24, right: 24 })
          Button('授予相机权限')
            .onClick(() => {
              this.requestPermission();
            })
            .backgroundColor('#FF9F4A')
            .fontColor('#07080A')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#07080A')
      } else {
        Column() {
          // 顶部镜头栏
          Row() {
            ForEach(this.cameras.filter((c) => !c.isFrontFacing()), (camera: AstroCamera) => {
              Text(camera.label)
                .fontSize(14)
                .fontColor(this.selectedCamera?.id === camera.id ? '#FF9F4A' : '#8B909B')
                .fontWeight(this.selectedCamera?.id === camera.id ? FontWeight.Medium : FontWeight.Normal)
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .onClick(() => this.selectCamera(camera))
            }, (camera: AstroCamera) => camera.id)
            Blank()
            Text('调焦')
              .fontSize(14)
              .fontColor(this.showTuning ? '#FF9F4A' : '#8B909B')
              .padding(8)
              .onClick(() => {
                this.showTuning = !this.showTuning;
              })
            Text('设置')
              .fontSize(14)
              .fontColor('#8B909B')
              .padding(8)
              .onClick(() => this.openSettings())
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .backgroundColor('#07080A')

          // 预览区域
          Stack() {
            XComponent({
              type: XComponentType.SURFACE,
              controller: this.xComponentController
            })
              .onLoad(() => this.onXComponentLoad())
              .width('100%')
              .height('100%')

            if (this.phase === 'capturing') {
              Column({ space: 4 }) {
                Text(this.framesTarget > 0 ? `${this.framesDone}/${this.framesTarget} 帧` : `${this.framesDone} 帧`)
                  .fontSize(16)
                  .fontColor('#F3F4F7')
                Text(this.formatElapsed(this.elapsedMs))
                  .fontSize(12)
                  .fontColor('#8B909B')
              }
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .backgroundColor('#B3000000')
              .borderRadius(12)
              .position({ x: 14, y: 14 })
            }

            if (this.countdown >= 0) {
              Text(`${this.countdown}`)
                .fontSize(72)
                .fontColor('#FF9F4A')
                .backgroundColor('#B3000000')
                .width(128)
                .height(128)
                .textAlign(TextAlign.Center)
                .borderRadius(64)
              .alignSelf(ItemAlign.Center)
            }

            if (this.message !== '') {
              Text(this.message)
                .fontSize(13)
                .fontColor('#F3F4F7')
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .backgroundColor('#B3000000')
                .borderRadius(20)
                .onClick(() => {
                  this.message = '';
                })
                .position({ x: 14, y: '70%' })
            }
          }
          .layoutWeight(1)
          .width('100%')
          .backgroundColor('#000000')

          // 底部控制
          Column({ space: 10 }) {
            if (this.showTuning) {
              Column({ space: 8 }) {
                Button('一键星空优化')
                  .width('100%')
                  .fontSize(13)
                  .fontColor('#07080A')
                  .backgroundColor('#FF9F4A')
                  .onClick(() => this.applyAstroPreset())
                Row() {
                  Text('对焦')
                  Blank()
                  Text(this.focusValue >= 0.99 ? '∞' : this.focusValue.toFixed(2))
                }
                .width('100%')
                Slider({ value: this.focusValue, min: 0, max: 1, step: 0.01 })
                  .onChange((value: number) => this.onFocusChange(value))
                  .selectedColor('#FF9F4A')

                Row() {
                  Text('变焦')
                  Blank()
                  Text(`${this.zoomValue.toFixed(1)}x`)
                }
                .width('100%')
                Slider({
                  value: this.zoomValue,
                  min: this.selectedCamera?.zoomMin ?? 1,
                  max: this.selectedCamera?.zoomMax ?? 1,
                  step: 0.1
                })
                  .onChange((value: number) => this.onZoomChange(value))
                  .selectedColor('#FF9F4A')

                Row() {
                  Text('亮度')
                  Blank()
                  Text(`${this.evValue >= 0 ? '+' : ''}${this.evValue.toFixed(1)} EV`)
                }
                .width('100%')
                Slider({ value: this.evValue, min: -3, max: 3, step: 0.1 })
                  .onChange((value: number) => this.onEvChange(value))
                  .selectedColor('#FF9F4A')

                Row() {
                  Text('白平衡')
                  Blank()
                  Text(this.whiteBalanceLabel(this.whiteBalanceMode))
                }
                .width('100%')
                Row({ space: 6 }) {
                  ForEach([0, 1, 2, 3, 4, 5], (mode: number) => {
                    Text(this.whiteBalanceLabel(mode))
                      .fontSize(11)
                      .fontColor(this.whiteBalanceMode === mode ? '#07080A' : '#8B909B')
                      .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                      .backgroundColor(this.whiteBalanceMode === mode ? '#FF9F4A' : '#101217')
                      .borderRadius(8)
                      .onClick(() => this.onWhiteBalanceModeChange(mode))
                  }, (mode: number) => mode.toString())
                }
                .width('100%')

                if (this.whiteBalanceMode === 5) {
                  Row() {
                    Text('色温')
                    Blank()
                    Text(`${this.whiteBalanceKelvin}K`)
                  }
                  .width('100%')
                  Slider({
                    value: this.whiteBalanceKelvin,
                    min: this.selectedCamera?.whiteBalanceMin ?? 2800,
                    max: this.selectedCamera?.whiteBalanceMax ?? 10000,
                    step: 100
                  })
                    .onChange((value: number) => this.onWhiteBalanceKelvinChange(value))
                    .selectedColor('#FF9F4A')
                }

                if ((this.selectedCamera?.apertureValues.length ?? 0) > 0) {
                  Row() {
                    Text('光圈')
                    Blank()
                    Text(this.apertureValue > 0 ? `f/${this.apertureValue.toFixed(1)}` : '自动')
                  }
                  .width('100%')
                  Row({ space: 6 }) {
                    Text('自动')
                      .fontSize(11)
                      .fontColor(this.apertureValue <= 0 ? '#07080A' : '#8B909B')
                      .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                      .backgroundColor(this.apertureValue <= 0 ? '#FF9F4A' : '#101217')
                      .borderRadius(8)
                      .onClick(() => this.onApertureChange(0))
                    ForEach(this.selectedCamera?.apertureValues ?? [], (aperture: number) => {
                      Text(`f/${aperture.toFixed(1)}`)
                        .fontSize(11)
                        .fontColor(this.apertureValue === aperture ? '#07080A' : '#8B909B')
                        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                        .backgroundColor(this.apertureValue === aperture ? '#FF9F4A' : '#101217')
                        .borderRadius(8)
                        .onClick(() => this.onApertureChange(aperture))
                    }, (aperture: number) => aperture.toString())
                  }
                  .width('100%')
                }
              }
              .padding(12)
              .backgroundColor('#181B22')
              .borderRadius(14)
            }

            Text(this.phase === 'metering' ? '正在读取天空…' :
              (this.phase === 'saving' ? '正在生成照片…' : this.planReadout(this.plan)))
              .fontSize(14)
              .fontColor('#F3F4F7')
              .textAlign(TextAlign.Center)

            Row() {
              ForEach([CaptureMode.SINGLE, CaptureMode.TEN_SECONDS, CaptureMode.THIRTY_SECONDS, CaptureMode.INDEFINITE],
                (m: CaptureMode) => {
                  Text(captureModeLabel(m))
                    .fontSize(13)
                    .fontColor(this.mode === m ? '#07080A' : '#8B909B')
                    .fontWeight(this.mode === m ? FontWeight.Medium : FontWeight.Normal)
                    .textAlign(TextAlign.Center)
                    .layoutWeight(1)
                    .padding({ top: 9, bottom: 9 })
                    .backgroundColor(this.mode === m ? '#FF9F4A' : '#181B22')
                    .borderRadius(10)
                    .onClick(() => this.selectMode(m))
                }, (m: CaptureMode) => m.toString())
            }
            .width('100%')
            .padding(3)
            .backgroundColor('#181B22')
            .borderRadius(13)

            Row() {
              Text(this.lastSavedName !== '' ? '已保存' : '')
                .fontSize(12)
                .fontColor('#8B909B')
                .width(64)
              Button(this.phase === 'capturing' ? '停止' : (this.countdown >= 0 ? '取消' : '拍摄'))
                .width(140)
                .height(64)
                .fontSize(18)
                .fontColor('#07080A')
                .backgroundColor(this.phase === 'capturing' ? '#FF5F4A' : '#FFFFFF')
                .borderRadius(32)
                .onClick(() => this.onShutter())
              Text(this.timerSeconds === 0 ? '定时关' : `${this.timerSeconds}秒`)
                .fontSize(12)
                .fontColor(this.timerSeconds === 0 ? '#8B909B' : '#FF9F4A')
                .width(64)
                .textAlign(TextAlign.Center)
                .onClick(() => this.onTimerChange())
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 12 })
          .backgroundColor('#101217')
          .borderRadius({ topLeft: 22, topRight: 22 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#07080A')
      }
    }
    .width('100%')
    .height('100%')
  }
}

class IndexCaptureCallbacks extends CaptureCallbacks {
  private page: Index;

  constructor(page: Index) {
    super();
    this.page = page;
  }

  onFrameStacked(done: number, target: number, shiftX: number, shiftY: number): void {
    this.page.framesDone = done;
    this.page.framesTarget = target === Number.MAX_SAFE_INTEGER ? 0 : target;
  }

  onExposureConfirmed(exposureUs: number, iso: number): void {
    hilog.info(0x0000, TAG, 'honoured %{public}d us ISO %{public}d', exposureUs, iso);
  }

  onStopping(): void {
    this.page.phase = 'saving';
    this.page.stopElapsedTimer();
  }

  onCaptureComplete(jpeg: ArrayBuffer | null, frames: number, integrationMs: number): void {
    this.page.phase = 'ready';
    if (jpeg && frames > 0) {
      this.page.saveJpeg(jpeg, frames, integrationMs);
    } else {
      this.page.message = '本次拍摄没有产生有效帧';
    }
  }

  onError(message: string): void {
    this.page.phase = 'ready';
    this.page.message = message;
  }
}
