> 标题：Interface (ColorManagementQuery)
> 来源：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-camera-colormanagementquery
> 文档ID：document/cn/harmonyos-references/arkts-apis-camera-colormanagementquery

# Interface (ColorManagementQuery)

色彩管理类，用于查询色彩空间参数。  
![](https://media:201786643164745039)  
* 本模块首批接口从API version 10开始支持。后续版本的新增接口，采用上角标单独标记接口的起始版本。
* 本Interface首批接口从API version 12开始支持。  

#### 导入模块

```
import { camera } from '@kit.CameraKit';
```

#### getSupportedColorSpaces^12+^

getSupportedColorSpaces(): Array\<colorSpaceManager.ColorSpace\>

获取支持的色彩空间列表。

元服务API： 从API version 19开始，该接口支持在元服务中使用。

系统能力： SystemCapability.Multimedia.Camera.Core

返回值：  

|类型|说明|
|:----------------------------------------------------------------------------------------------------------------------------------------------|:-----------------------------|
|Array\<[colorSpaceManager.ColorSpace](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-colorspacemanager#colorspace)\>|支持的色彩空间列表。若接口调用失败，返回undefined。|

错误码：

以下错误码的详细介绍请参见[Camera错误码](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/errorcode-camera)。  

|错误码ID|错误信息|
|:------|:----------------------------------------------------------|
|7400103|Session not config, only throw in session usage. 适用版本：12-17|

示例：

```
import { colorSpaceManager } from '@kit.ArkGraphics2D';

function getSupportedColorSpaces(session: camera.PhotoSession): Array<colorSpaceManager.ColorSpace> {
  let colorSpaces: Array<colorSpaceManager.ColorSpace> = [];
  colorSpaces = session.getSupportedColorSpaces();
  return colorSpaces;
}
```
