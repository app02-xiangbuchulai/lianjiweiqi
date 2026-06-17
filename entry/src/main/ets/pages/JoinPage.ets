import router from '@ohos.router';

@Entry
@Component
struct JoinPage {
  @State roomId: string = ''
  private serverUrl: string = ''

  aboutToAppear(): void {
    let p = router.getParams() as Record<string, string>
    this.serverUrl = p['serverUrl'] || ''
  }

  build() {
    Column({ space: 20 }) {
      Text('加入房间')
        .fontSize(28).fontWeight(FontWeight.Bold).margin({ bottom: 30 })

      TextInput({ placeholder: '请输入4位房间号' })
        .width(300).height(50)
        .onChange((v) => this.roomId = v)

      Button('确认加入')
        .width(200).height(50)
        .onClick(() => {
          if (this.roomId !== '') {
            router.pushUrl({
              url: 'pages/Index',
              params: { mode: 'join', roomId: this.roomId, serverUrl: this.serverUrl }
            })
          }
        })
    }
    .width('100%').height('100%')
    .backgroundColor('#FFF8DC')
    .justifyContent(FlexAlign.Center)
  }
}