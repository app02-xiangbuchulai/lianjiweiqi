import router from '@ohos.router';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct MainPage {
  @State serverIp: string = '192.168.1.100'

  build() {
    Column({ space: 30 }) {
      Text('联机围棋')
        .fontSize(56)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3728')
        .margin({ bottom: 20 })

      Text('联机对战版')
        .fontSize(16)
        .fontColor('#8B7355')
        .margin({ bottom: 40 })

      Text('服务器IP（电脑IP）')
        .fontSize(14)
        .fontColor('#666')
      TextInput({ text: this.serverIp })
        .width(260)
        .height(45)
        .onChange((v) => this.serverIp = v)

      Button('本地对战')
        .width(260).height(55).fontSize(18)
        .backgroundColor('#DEB887')
        .onClick(() => {
          router.pushUrl({ url: 'pages/Index', params: { mode: 'local' } });
        })

      Button('创建房间（执黑）')
        .width(260).height(55).fontSize(18)
        .backgroundColor('#8FBC8F')
        .onClick(() => {
          router.pushUrl({
            url: 'pages/Index',
            params: { mode: 'create', serverUrl: `http://${this.serverIp}:8080` }
          });
        })

      Button('加入房间（执白）')
        .width(260).height(55).fontSize(18)
        .backgroundColor('#87CEEB')
        .onClick(() => {
          router.pushUrl({ url: 'pages/JoinPage', params: { serverUrl: `http://${this.serverIp}:8080` } });
        })
    }
    .width('100%').height('100%')
    .backgroundColor('#FFF8DC')
    .justifyContent(FlexAlign.Center)
  }
}