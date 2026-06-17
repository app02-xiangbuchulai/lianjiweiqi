import { GameState } from '../model/GameState'
import { GameBoard } from '../components/GameBoard'
import { GameNetwork, NetMessage } from '../network/GameNetwork'
import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State gameState: GameState = new GameState()
  @State mode: string = 'local'
  @State myRole: number = 1
  @State isMyTurn: boolean = true
  @State statusText: string = '本地对局'
  @State roomId: string = ''
  private network: GameNetwork = new GameNetwork()
  private checkTimer: number = -1
  private lastSentRow: number = -1
  private lastSentCol: number = -1
  private hasPassed: boolean = false

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>
    this.mode = params['mode'] || 'local'

    if (this.mode === 'local') {
      this.isMyTurn = true
      this.statusText = '本地对局'
    }
    else if (this.mode === 'create') {
      this.myRole = 1
      this.isMyTurn = true
      this.statusText = '正在创建房间...'
      this.network.setServerUrl(params['serverUrl'] || '')
      this.network.setOnData((data: NetMessage): void => this.onNetworkData(data))
      this.network.createRoom().then((id: string): void => {
        this.roomId = id
        this.statusText = '房间号:' + id + ', 等待对手加入...'
        console.info('创建房间成功，房间号:', id)
      }).catch((err: Error): void => {
        this.statusText = '创建失败:' + err.message
        console.error('创建房间失败:', err)
      })
      this.startCheckTimer()
    }
    else if (this.mode === 'join') {
      this.myRole = 2
      this.isMyTurn = false
      this.roomId = params['roomId'] || ''
      this.statusText = '正在加入房间...'
      this.network.setServerUrl(params['serverUrl'] || '')
      this.network.setOnData((data: NetMessage): void => this.onNetworkData(data))
      this.network.joinRoom(this.roomId).then((ok: boolean): void => {
        this.statusText = ok ? '加入成功，等待黑方落子...' : '加入失败'
        console.info('加入房间结果:', ok)
      }).catch((err: Error): void => {
        this.statusText = '加入失败:' + err.message
        console.error('加入房间失败:', err)
      })
      this.startCheckTimer()
    }
  }

  aboutToDisappear(): void {
    this.network.close()
    if (this.checkTimer !== -1) {
      clearInterval(this.checkTimer)
    }
  }

  startCheckTimer(): void {
    this.checkTimer = setInterval(() => this.checkAndSendMove(), 200)
  }

  checkAndSendMove(): void {
    if (this.mode === 'local') return
    if (!this.isMyTurn) return

    let row: number = this.gameState.getLastMoveRow()
    let col: number = this.gameState.getLastMoveCol()

    if (this.hasPassed) {
      if (this.lastSentRow === -2) return
      this.lastSentRow = -2
      this.lastSentCol = -2
      this.hasPassed = false
      this.network.send({ type: 'pass' })
      this.isMyTurn = false
      this.statusText = '已发送Pass，等待对手...'
      return
    }

    if (row === -1 || col === -1) return

    if (this.lastSentRow !== row || this.lastSentCol !== col) {
      this.lastSentRow = row
      this.lastSentCol = col
      this.network.send({ type: 'move', row: row, col: col })
      this.isMyTurn = false
      this.statusText = '已发送，等待对手...'

      if (this.gameState.isGameOver()) {
        this.showGameResult()
      }
    }
  }

  onNetworkData(data: NetMessage): void {
    if (data.type === 'move' && data.row !== undefined && data.col !== undefined) {
      this.gameState.makeMove(data.row, data.col)
      this.isMyTurn = true
      this.statusText = '轮到你了'

      // ✅ 关键修复：同步 lastSent，防止 checkTimer 误判
      this.lastSentRow = data.row
      this.lastSentCol = data.col

      if (this.gameState.isGameOver()) {
        this.showGameResult()
      }
    } else if (data.type === 'pass') {
      this.gameState.pass()
      this.isMyTurn = true
      this.statusText = '对方Pass，轮到你了'

      // ✅ 同步 Pass 状态
      this.lastSentRow = -2
      this.lastSentCol = -2

      if (this.gameState.isGameOver()) {
        this.showGameResult()
      }
    }
  }

  showGameResult(): void {
    const black = this.gameState.getBlackScore()
    const white = this.gameState.getWhiteScore()
    this.statusText = `游戏结束! 黑方得分:${black} 白方得分:${white}`
  }

  handlePass(): void {
    if (!this.isMyTurn) return
    this.gameState.pass()
    this.isMyTurn = false
    this.hasPassed = true
    this.statusText = '已Pass，等待对手...'
    if (this.gameState.isGameOver()) {
      this.showGameResult()
    }
  }

  build() {
    Column() {
      Row() {
        Text('围棋').fontSize(28).fontWeight(FontWeight.Bold)
        Text(this.statusText).fontSize(14).margin({ left: 15 }).fontColor('#666')
      }
      .width('100%').height(60).padding({ left: 20, right: 20 }).backgroundColor('#F5F5F5')

      if (this.mode !== 'local') {
        Text(this.statusText.includes('房间号') ? this.statusText : `房间: ${this.roomId} | 角色: ${this.myRole === 1 ? '黑方' : '白方'}`)
          .fontSize(14).margin(10).fontColor('#333')
      }

      Text(`黑方得分: ${this.gameState.getBlackScore()} | 白方得分: ${this.gameState.getWhiteScore()}`)
        .fontSize(14).margin(5).fontColor('#333')

      Column() {
        GameBoard({
          gameState: $gameState,
          isMyTurn: this.isMyTurn,
          isGameOver: this.gameState.isGameOver()
        })
          .width('100%').margin({ top: 10, bottom: 10 })
      }
      .width('100%').height('70%').justifyContent(FlexAlign.Center)

      if (!this.gameState.isGameOver()) {
        Button('Pass(虚手)')
          .width(120).height(40)
          .backgroundColor('#8B4513')
          .fontColor('#FFFFFF')
          .onClick(() => this.handlePass())
          .margin({ bottom: 10 })
      }
    }
    .width('100%').height('100%').backgroundColor('#FFFFFF')
  }
}