# Camera Kit 鸿蒙开发知识库（MCP）

本目录通过鸿蒙开发者知识 MCP 服务（`https://connect-api.cloud.huawei.com/api/developerknowledge/mcp`）抓取并整理了 **Camera Kit（相机服务）** 的 ArkTS 相关知识，便于本地检索、喂给 MCP 客户端或作为开发参考资料。

## 目录结构

```
camera-kit-mcp/
├── api/          # Camera Kit ArkTS API 模块文档（@ohos.multimedia.camera、@ohos.multimedia.cameraPicker 等）
├── guides/       # 开发相机应用必选能力(ArkTS)、开发相机应用基础能力(ArkTS) 各板块指南
├── scripts/      # 抓取与生成脚本（可重新拉取最新文档）
├── manifest.json # 已抓取文档清单
├── mcp.json      # 鸿蒙开发者知识 MCP 远程服务配置（供 MCP 客户端使用）
└── README.md
```

## 快速使用

- 直接阅读 `api/` 与 `guides/` 下的 Markdown 文件。
- 将本目录作为本地知识库接入支持文件/文件夹检索的 MCP 客户端或 RAG 工具（例如使用 filesystem MCP 指向本目录）。
- 如需重新同步官方最新内容，运行：

```bash
python scripts/fetch_camera_kit.py
python scripts/generate_readme.py
```

## 官方 MCP 服务配置

如需继续使用官方远程 MCP，可将 `mcp.json` 中的配置加入支持 MCP 的 AI 客户端（如 DevEco Studio）。

```json
{
  "mcpServers": {
    "harmonyos_developer_knowledge": {
      "url": "https://connect-api.cloud.huawei.com/api/developerknowledge/mcp",
      "type": "http"
    }
  }
}
```

## 统计

- ArkTS API 文档：55 篇
- ArkTS 开发指南：49 篇
- 抓取时间：2026-08-16T10:34:04+00:00

## ArkTS API 文档

| 文档 | 标题 | 来源 |
| --- | --- | --- |
| [arkts-apis-camera-aperture](api/arkts-apis-camera-aperture.md) | Interface (Aperture) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-aperture |
| [arkts-apis-camera-aperturequery](api/arkts-apis-camera-aperturequery.md) | Interface (ApertureQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-aperturequery |
| [arkts-apis-camera-autodeviceswitch](api/arkts-apis-camera-autodeviceswitch.md) | Interface (AutoDeviceSwitch) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-autodeviceswitch |
| [arkts-apis-camera-autodeviceswitchquery](api/arkts-apis-camera-autodeviceswitchquery.md) | Interface (AutoDeviceSwitchQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-autodeviceswitchquery |
| [arkts-apis-camera-autoexposure](api/arkts-apis-camera-autoexposure.md) | Interface (AutoExposure) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-autoexposure |
| [arkts-apis-camera-autoexposurequery](api/arkts-apis-camera-autoexposurequery.md) | Interface (AutoExposureQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-autoexposurequery |
| [arkts-apis-camera-camerainput](api/arkts-apis-camera-camerainput.md) | Interface (CameraInput) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-camerainput |
| [arkts-apis-camera-cameramanager](api/arkts-apis-camera-cameramanager.md) | Interface (CameraManager) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-cameramanager |
| [arkts-apis-camera-cameraoutput](api/arkts-apis-camera-cameraoutput.md) | Interface (CameraOutput) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-cameraoutput |
| [arkts-apis-camera-capturephoto](api/arkts-apis-camera-capturephoto.md) | Interface (CapturePhoto) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-capturephoto |
| [arkts-apis-camera-capturesession](api/arkts-apis-camera-capturesession.md) | 废弃的Interface (CaptureSession, deprecated) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-capturesession |
| [arkts-apis-camera-colormanagement](api/arkts-apis-camera-colormanagement.md) | Interface (ColorManagement) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-colormanagement |
| [arkts-apis-camera-colormanagementquery](api/arkts-apis-camera-colormanagementquery.md) | Interface (ColorManagementQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-colormanagementquery |
| [arkts-apis-camera-controlcenter](api/arkts-apis-camera-controlcenter.md) | Interface (ControlCenter) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-controlcenter |
| [arkts-apis-camera-controlcenterquery](api/arkts-apis-camera-controlcenterquery.md) | Interface (ControlCenterQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-controlcenterquery |
| [arkts-apis-camera-e](api/arkts-apis-camera-e.md) | Enums | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-e |
| [arkts-apis-camera-f](api/arkts-apis-camera-f.md) | Functions | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-f |
| [arkts-apis-camera-flash](api/arkts-apis-camera-flash.md) | Interface (Flash) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-flash |
| [arkts-apis-camera-flashquery](api/arkts-apis-camera-flashquery.md) | Interface (FlashQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-flashquery |
| [arkts-apis-camera-focus](api/arkts-apis-camera-focus.md) | Interface (Focus) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-focus |
| [arkts-apis-camera-focusquery](api/arkts-apis-camera-focusquery.md) | Interface (FocusQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-focusquery |
| [arkts-apis-camera-i](api/arkts-apis-camera-i.md) | Interfaces (其他) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-i |
| [arkts-apis-camera-macro](api/arkts-apis-camera-macro.md) | Interface (Macro) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-macro |
| [arkts-apis-camera-macroquery](api/arkts-apis-camera-macroquery.md) | Interface (MacroQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-macroquery |
| [arkts-apis-camera-manualexposure](api/arkts-apis-camera-manualexposure.md) | Interface (ManualExposure) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-manualexposure |
| [arkts-apis-camera-manualexposurequery](api/arkts-apis-camera-manualexposurequery.md) | Interface (ManualExposureQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-manualexposurequery |
| [arkts-apis-camera-manualfocus](api/arkts-apis-camera-manualfocus.md) | Interface (ManualFocus) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-manualfocus |
| [arkts-apis-camera-manualfocusquery](api/arkts-apis-camera-manualfocusquery.md) | Interface (ManualFocusQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-manualfocusquery |
| [arkts-apis-camera-manualiso](api/arkts-apis-camera-manualiso.md) | Interface (ManualIso) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-manualiso |
| [arkts-apis-camera-manualisoquery](api/arkts-apis-camera-manualisoquery.md) | Interface (ManualIsoQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-manualisoquery |
| [arkts-apis-camera-metadataoutput](api/arkts-apis-camera-metadataoutput.md) | Interface (MetadataOutput) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-metadataoutput |
| [arkts-apis-camera-ois](api/arkts-apis-camera-ois.md) | Interface (OIS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-ois |
| [arkts-apis-camera-oisquery](api/arkts-apis-camera-oisquery.md) | Interface (OISQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-oisquery |
| [arkts-apis-camera-photo](api/arkts-apis-camera-photo.md) | Interface (Photo) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-photo |
| [arkts-apis-camera-photooutput](api/arkts-apis-camera-photooutput.md) | Interface (PhotoOutput) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-photooutput |
| [arkts-apis-camera-photosession](api/arkts-apis-camera-photosession.md) | Interface (PhotoSession) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-photosession |
| [arkts-apis-camera-previewoutput](api/arkts-apis-camera-previewoutput.md) | Interface (PreviewOutput) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-previewoutput |
| [arkts-apis-camera-securesession](api/arkts-apis-camera-securesession.md) | Interface (SecureSession) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-securesession |
| [arkts-apis-camera-session](api/arkts-apis-camera-session.md) | Interface (Session) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-session |
| [arkts-apis-camera-stabilization](api/arkts-apis-camera-stabilization.md) | Interface (Stabilization) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-stabilization |
| [arkts-apis-camera-stabilizationquery](api/arkts-apis-camera-stabilizationquery.md) | Interface (StabilizationQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-stabilizationquery |
| [arkts-apis-camera-t](api/arkts-apis-camera-t.md) | Types | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-t |
| [arkts-apis-camera-videooutput](api/arkts-apis-camera-videooutput.md) | Interface (VideoOutput) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-videooutput |
| [arkts-apis-camera-videosession](api/arkts-apis-camera-videosession.md) | Interface (VideoSession) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-videosession |
| [arkts-apis-camera-whitebalance](api/arkts-apis-camera-whitebalance.md) | Interface (WhiteBalance) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-whitebalance |
| [arkts-apis-camera-whitebalancequery](api/arkts-apis-camera-whitebalancequery.md) | Interface (WhiteBalanceQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-whitebalancequery |
| [arkts-apis-camera-zoom](api/arkts-apis-camera-zoom.md) | Interface (Zoom) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-zoom |
| [arkts-apis-camera-zoomquery](api/arkts-apis-camera-zoomquery.md) | Interface (ZoomQuery) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-zoomquery |
| [arkts-apis-camera](api/arkts-apis-camera.md) | 模块描述 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera |
| [camera-api](api/camera-api.md) | Camera Kit（相机服务） | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/camera-api |
| [camera-arkts-errcode](api/camera-arkts-errcode.md) | 错误码 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/camera-arkts-errcode |
| [camera-arkts](api/camera-arkts.md) | ArkTS API | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/camera-arkts |
| [errorcode-camera](api/errorcode-camera.md) | Camera错误码 | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/errorcode-camera |
| [js-apis-camera](api/js-apis-camera.md) | @ohos.multimedia.camera (相机管理) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-camera |
| [js-apis-camerapicker](api/js-apis-camerapicker.md) | @ohos.multimedia.cameraPicker (相机选择器) | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-camerapicker |

## 开发相机应用基础能力(ArkTS) 及必选能力指南

| 文档 | 标题 | 来源 |
| --- | --- | --- |
| [camera-animation](guides/camera-animation.md) | 相机基础动效(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-animation |
| [camera-api-faq](guides/camera-api-faq.md) | 相机API调用时序问题 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-api-faq |
| [camera-auto-switch](guides/camera-auto-switch.md) | 自动切换摄像头实践(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-auto-switch |
| [camera-background-recovery](guides/camera-background-recovery.md) | 相机启动恢复实践(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-background-recovery |
| [camera-concurrent-open](guides/camera-concurrent-open.md) | 多摄同开(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-concurrent-open |
| [camera-control-center](guides/camera-control-center.md) | 相机控制器(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-control-center |
| [camera-deferred-capture-case](guides/camera-deferred-capture-case.md) | 分段式拍照实践(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-deferred-capture-case |
| [camera-deferred-capture](guides/camera-deferred-capture.md) | 分段式拍照(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-deferred-capture |
| [camera-dev-arkts-mandatory](guides/camera-dev-arkts-mandatory.md) | 开发相机应用必选能力(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-dev-arkts-mandatory |
| [camera-dev-arkts](guides/camera-dev-arkts.md) | 开发相机应用基础能力(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-dev-arkts |
| [camera-dev-faq-start](guides/camera-dev-faq-start.md) | 相机无法启动 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-dev-faq-start |
| [camera-dev-faq](guides/camera-dev-faq.md) | Camera Kit常见问题 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-dev-faq |
| [camera-device-input](guides/camera-device-input.md) | 设备输入(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-device-input |
| [camera-device-management](guides/camera-device-management.md) | 相机管理(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-device-management |
| [camera-dual-channel-preview](guides/camera-dual-channel-preview.md) | 双路预览(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-dual-channel-preview |
| [camera-focus](guides/camera-focus.md) | 对焦(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-focus |
| [camera-foldable-display](guides/camera-foldable-display.md) | 适配不同折叠状态的摄像头变更(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-foldable-display |
| [camera-framerate](guides/camera-framerate.md) | 动态调整预览帧率(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-framerate |
| [camera-hdr-recording](guides/camera-hdr-recording.md) | HDR Vivid相机录像(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-hdr-recording |
| [camera-hdr-shooting](guides/camera-hdr-shooting.md) | HDR Vivid相机拍照(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-hdr-shooting |
| [camera-kit](guides/camera-kit.md) | Camera Kit（相机服务） | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-kit |
| [camera-macro](guides/camera-macro.md) | 微距能力设置(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-macro |
| [camera-metadata](guides/camera-metadata.md) | 元数据（ArkTS） | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-metadata |
| [camera-moving-photo](guides/camera-moving-photo.md) | 动态照片拍摄(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-moving-photo |
| [camera-overview](guides/camera-overview.md) | Camera Kit简介 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-overview |
| [camera-picker](guides/camera-picker.md) | 通过系统相机拍照和录像(CameraPicker) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-picker |
| [camera-preconfig](guides/camera-preconfig.md) | 使用相机预配置(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-preconfig |
| [camera-preparation](guides/camera-preparation.md) | 申请相机开发的权限 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-preparation |
| [camera-preview-glitch-solution](guides/camera-preview-glitch-solution.md) | 相机预览花屏解决方案 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-preview-glitch-solution |
| [camera-preview](guides/camera-preview.md) | 预览(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-preview |
| [camera-previewoutput-faq](guides/camera-previewoutput-faq.md) | 相机预览流启动问题 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-previewoutput-faq |
| [camera-recording-case](guides/camera-recording-case.md) | 录像实践(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-recording-case |
| [camera-recording](guides/camera-recording.md) | 录像(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-recording |
| [camera-rotation-angle-adaptation](guides/camera-rotation-angle-adaptation.md) | 适配相机旋转角度(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-rotation-angle-adaptation |
| [camera-rotation-faq](guides/camera-rotation-faq.md) | 相机预览画面旋转异常问题 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-rotation-faq |
| [camera-rotation-term](guides/camera-rotation-term.md) | 相机旋转角度的术语 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-rotation-term |
| [camera-rotation](guides/camera-rotation.md) | 相机旋转 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-rotation |
| [camera-secure-photo](guides/camera-secure-photo.md) | 安全相机(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-secure-photo |
| [camera-session-management](guides/camera-session-management.md) | 会话管理(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-session-management |
| [camera-sessionconfig-faq](guides/camera-sessionconfig-faq.md) | 会话配置问题 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-sessionconfig-faq |
| [camera-shooting-case](guides/camera-shooting-case.md) | 拍照实践(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-shooting-case |
| [camera-shooting](guides/camera-shooting.md) | 拍照(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-shooting |
| [camera-system-pressure](guides/camera-system-pressure.md) | 压力管控(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-system-pressure |
| [camera-torch-use](guides/camera-torch-use.md) | 手电筒使用(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-torch-use |
| [camera-whitebalance-faq](guides/camera-whitebalance-faq.md) | 白平衡相关问题 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-whitebalance-faq |
| [camera-whitebalance](guides/camera-whitebalance.md) | 白平衡设置(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-whitebalance |
| [camera-worker](guides/camera-worker.md) | 在Worker线程中使用相机(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-worker |
| [camera-yuv-shooting](guides/camera-yuv-shooting.md) | YUV拍照(ArkTS) | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-yuv-shooting |
| [devicesecurity-taas-securecamera](guides/devicesecurity-taas-securecamera.md) | 安全摄像头场景 | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/devicesecurity-taas-securecamera |
