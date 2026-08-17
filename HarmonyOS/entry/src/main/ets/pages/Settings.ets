import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { Settings as SettingsModel, SettingsStore } from '../model/SettingsStore';

@Entry
@Component
struct Settings {
  @State alignFrames: boolean = true;
  @State autoStretch: boolean = true;
  @State evOffset: number = 0;
  @State timerSeconds: number = 3;
  @State focusDistance: number = 1;
  @State zoomRatio: number = 1;
  @State whiteBalanceMode: number = 0;
  @State whiteBalanceKelvin: number = 5000;
  @State apertureValue: number = 0;
  private settingsStore: SettingsStore | null = null;

  aboutToAppear(): void {
    this.init();
  }

  private async init(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.settingsStore = new SettingsStore(ctx);
    await this.settingsStore.init();
    const s = await this.settingsStore.load();
    this.alignFrames = s.alignFrames;
    this.autoStretch = s.autoStretch;
    this.evOffset = s.evOffset;
    this.timerSeconds = s.timerSeconds;
    this.focusDistance = s.focusDistance;
    this.zoomRatio = s.zoomRatio;
    this.whiteBalanceMode = s.whiteBalanceMode;
    this.whiteBalanceKelvin = s.whiteBalanceKelvin;
    this.apertureValue = s.apertureValue;
  }

  private save(): void {
    if (!this.settingsStore) {
      return;
    }
    const s = new SettingsModel();
    s.alignFrames = this.alignFrames;
    s.autoStretch = this.autoStretch;
    s.evOffset = this.evOffset;
    s.timerSeconds = this.timerSeconds;
    s.focusDistance = this.focusDistance;
    s.zoomRatio = this.zoomRatio;
    s.whiteBalanceMode = this.whiteBalanceMode;
    s.whiteBalanceKelvin = this.whiteBalanceKelvin;
    s.apertureValue = this.apertureValue;
    this.settingsStore.save(s);
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor('#F3F4F7')
          .padding(10)
          .onClick(() => router.back())
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F3F4F7')
          .padding({ left: 8 })
        Blank()
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .backgroundColor('#07080A')

      Scroll() {
        Column({ space: 12 }) {
          Text('叠加')
            .fontSize(12)
            .fontColor('#FF9F4A')
            .letterSpacing(1.4)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 8, left: 4 })

          Column() {
            Row() {
              Column() {
                Text('对齐星点')
                  .fontSize(15)
                  .fontColor('#F3F4F7')
                Text('天空转动时自动平移对齐每帧，避免长时叠加拖出星轨。')
                  .fontSize(12)
                  .fontColor('#8B909B')
                  .margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.alignFrames })
                .selectedColor('#FF9F4A')
                .onChange((isOn: boolean) => {
                  this.alignFrames = isOn;
                  this.save();
                })
            }
            .width('100%')
            .padding(16)

            Divider().color('#262A33')

            Row() {
              Column() {
                Text('自动拉伸')
                  .fontSize(15)
                  .fontColor('#F3F4F7')
                Text('叠加后的夜空常暗到看不见，自动拉伸可把暗部细节拉出来。')
                  .fontSize(12)
                  .fontColor('#8B909B')
                  .margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.autoStretch })
                .selectedColor('#FF9F4A')
                .onChange((isOn: boolean) => {
                  this.autoStretch = isOn;
                  this.save();
                })
            }
            .width('100%')
            .padding(16)
          }
          .width('100%')
          .backgroundColor('#101217')
          .borderRadius(16)

          Text('拍摄')
            .fontSize(12)
            .fontColor('#FF9F4A')
            .letterSpacing(1.4)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 8, left: 4 })

          Column({ space: 12 }) {
            Row() {
              Text('倒计时')
                .fontSize(15)
                .fontColor('#F3F4F7')
              Blank()
              Text(this.timerSeconds === 0 ? '关闭' : `${this.timerSeconds} 秒`)
                .fontSize(14)
                .fontColor('#FF9F4A')
            }
            .width('100%')
            .onClick(() => {
              this.timerSeconds = this.timerSeconds === 0 ? 3 : (this.timerSeconds === 3 ? 10 : 0);
              this.save();
            })

            Row() {
              Text('曝光补偿')
                .fontSize(15)
                .fontColor('#F3F4F7')
              Blank()
              Text(`${this.evOffset >= 0 ? '+' : ''}${this.evOffset.toFixed(1)} EV`)
                .fontSize(14)
                .fontColor('#FF9F4A')
            }
            .width('100%')
            Slider({ value: this.evOffset, min: -3, max: 3, step: 0.1 })
              .selectedColor('#FF9F4A')
              .onChange((value: number) => {
                this.evOffset = value;
                this.save();
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#101217')
          .borderRadius(16)

          Text('关于')
            .fontSize(12)
            .fontColor('#FF9F4A')
            .letterSpacing(1.4)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 8, left: 4 })

          Column({ space: 6 }) {
            Text('深空相机 HarmonyOS 版')
              .fontSize(16)
              .fontColor('#F3F4F7')
            Text('通过多帧短曝光叠加，在手机硬件限制下拍摄深空照片。')
              .fontSize(13)
              .fontColor('#8B909B')
            Text('版本 1.0.0')
              .fontSize(12)
              .fontColor('#565B66')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#101217')
          .borderRadius(16)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 30 })
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#07080A')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#07080A')
  }
}
