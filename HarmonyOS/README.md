# 深空相机（HarmonyOS 版）

基于安卓版 Deep Sky Camera 移植的鸿蒙原生应用，使用 ArkTS + Camera Kit 开发。

## 功能

- 相机预览（XComponent + Camera Kit PreviewOutput）
- 多帧短曝光叠加：单张、10 秒、30 秒、无限时长
- 自动规划单帧快门 / ISO / 帧数
- 星点平移对齐、自动拉伸
- 手动对焦 / 曝光补偿调节
- 变焦、白平衡（自动/预设/手动色温）、物理光圈调节
- 一键星空优化：自动切到广角、无限远对焦、日光白平衡
- 自拍倒计时
- 保存到图库（通过安全控件弹窗确认）

## 项目结构

```text
HarmonyOS/
├── AppScope/                 # 应用级配置与图标
├── entry/
│   ├── src/main/ets/
│   │   ├── entryability/     # UIAbility 入口
│   │   ├── pages/            # 主界面、设置页
│   │   ├── camera/           # 相机服务、叠加器、曝光规划
│   │   └── model/            # 设置持久化
│   └── src/main/resources/   # 资源、权限、页面路由
├── build-profile.json5       # 工程/签名配置
├── oh-package.json5
├── hvigorfile.ts
└── hvigor/
```

## 使用 DevEco Studio 打开

1. 使用 DevEco Studio 打开本目录（`HarmonyOS/`）。
2. 在 `build-profile.json5` 中配置你的签名（或使用 DevEco 自动签名）。
3. 确认 `products[].signingConfig` 已绑定到你的签名配置（例如 `"signingConfig": "default"`），否则安装时会报 `no signature file`。
4. 同步 `oh-package` 后运行到手机/模拟器。

## 已参考的官方能力

- Camera Kit ArkTS API：`@ohos.multimedia.camera`
- 双路预览：XComponent 显示 + ImageReceiver 获取 NV21 帧
- 手动曝光 / ISO / 对焦：`PhotoSession` + ManualExposure / ManualIso / ManualFocus
- 保存到图库：`photoAccessHelper.showAssetsCreationDialog`
