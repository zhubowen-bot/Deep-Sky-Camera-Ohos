import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'DeepSkySettings';

export class Settings {
  alignFrames: boolean = true;
  autoStretch: boolean = true;
  evOffset: number = 0;
  cameraId: string = '';
  focusDistance: number = 1;
  timerSeconds: number = 3;
  zoomRatio: number = 1;
  whiteBalanceMode: number = 0;
  whiteBalanceKelvin: number = 5000;
  apertureValue: number = 0;
}

export class SettingsStore {
  private context: common.UIAbilityContext;
  private pref?: preferences.Preferences;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async init(): Promise<void> {
    this.pref = await preferences.getPreferences(this.context, { name: 'deepsky_settings' });
  }

  async load(): Promise<Settings> {
    if (!this.pref) {
      await this.init();
    }
    const pref = this.pref;
    if (!pref) {
      throw new Error('preferences not initialized');
    }
    const s = new Settings();
    s.alignFrames = pref.getSync('align_frames', true) as boolean;
    s.autoStretch = pref.getSync('auto_stretch', true) as boolean;
    s.evOffset = pref.getSync('ev_offset', 0) as number;
    s.cameraId = pref.getSync('camera_id', '') as string;
    s.focusDistance = pref.getSync('focus_distance', 1) as number;
    s.timerSeconds = pref.getSync('timer_seconds', 3) as number;
    s.zoomRatio = pref.getSync('zoom_ratio', 1) as number;
    s.whiteBalanceMode = pref.getSync('white_balance_mode', 0) as number;
    s.whiteBalanceKelvin = pref.getSync('white_balance_kelvin', 5000) as number;
    s.apertureValue = pref.getSync('aperture_value', 0) as number;
    return s;
  }

  async save(s: Settings): Promise<void> {
    if (!this.pref) {
      await this.init();
    }
    const pref = this.pref;
    if (!pref) {
      throw new Error('preferences not initialized');
    }
    pref.putSync('align_frames', s.alignFrames);
    pref.putSync('auto_stretch', s.autoStretch);
    pref.putSync('ev_offset', s.evOffset);
    pref.putSync('camera_id', s.cameraId);
    pref.putSync('focus_distance', s.focusDistance);
    pref.putSync('timer_seconds', s.timerSeconds);
    pref.putSync('zoom_ratio', s.zoomRatio);
    pref.putSync('white_balance_mode', s.whiteBalanceMode);
    pref.putSync('white_balance_kelvin', s.whiteBalanceKelvin);
    pref.putSync('aperture_value', s.apertureValue);
    await pref.flush().catch((err: BusinessError) => {
      hilog.warn(0x0000, TAG, 'flush failed: %{public}s', JSON.stringify(err));
    });
  }
}
