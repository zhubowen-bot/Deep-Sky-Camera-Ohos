/**
 * 鸿蒙 Camera Kit 相机能力描述。
 * 从 CameraDevice 和 CameraOutputCapability 中读取，不写死硬件参数。
 */
export class AstroCamera {
  id: string = '';
  label: string = '';
  position: number = 0;
  cameraType: number = 0;
  focalLengthMm: number = 4.0;
  apertureF: number = 1.8;
  minExposureUs: number = 100;
  maxExposureUs: number = 100000;
  minIso: number = 50;
  maxIso: number = 800;
  pixelPitchUm: number = 1.0;
  previewWidth: number = 1920;
  previewHeight: number = 1080;
  sensorOrientation: number = 90;
  supportsManual: boolean = false;
  zoomMin: number = 1;
  zoomMax: number = 1;
  apertureValues: number[] = [];
  whiteBalanceMin: number = 2800;
  whiteBalanceMax: number = 10000;

  get maxExposureMs(): number {
    return Math.floor(this.maxExposureUs / 1000);
  }

  isFrontFacing(): boolean {
    return this.position === 2; // CameraPosition.CAMERA_POSITION_FRONT
  }
}
