import { GameState } from '../model/GameState'
import { display } from '@kit.ArkUI'

@Preview
@Component
export struct GameBoard {
  @Link gameState: GameState
  @Prop isMyTurn: boolean = true  // ✅ 新增：外部传入是否可点击
  @Prop isGameOver: boolean = false  // ✅ 新增：游戏结束状态
  @State private boardSize: number = 0
  @State private cellSize: number = 0
  @State private boardPadding: number = 8
  @State private showGameOverDialog: boolean = false
  @State private winnerText: string = ''
  zwidth: number = 0

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private canvascontext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  aboutToAppear(): void {
    this.calculateBoardSize()
  }

  private calculateBoardSize(): void {
    const screenWidth: number = this.zwidth == 0 ? px2vp(display.getDefaultDisplaySync().width) : this.zwidth
    this.boardSize = screenWidth - 2 * this.boardPadding
    this.cellSize = this.boardSize / (this.gameState.getBoardSize() - 1)
  }

  private handleClick(event: ClickEvent): void {
    // ✅ 修复：不是自己的回合或游戏结束，不处理点击
    if (!this.isMyTurn || this.isGameOver) {
      return
    }

    const x: number = event.x
    const y: number = event.y
    const col: number = Math.round(x / this.cellSize)
    const row: number = Math.round(y / this.cellSize)

    if (this.gameState.makeMove(row, col)) {
      if (this.gameState.isGameOver()) {
        const blackScore = this.gameState.getBlackScore()
        const whiteScore = this.gameState.getWhiteScore()
        this.winnerText = '游戏结束! 黑方得分:' + blackScore + ' 白方得分:' + whiteScore
        this.showGameOverDialog = true
      }
    }
  }

  private restartGame(): void {
    this.gameState.restart()
    this.showGameOverDialog = false
  }

  build() {
    Stack() {
      Rect()
        .width(this.boardSize + 2 * this.boardPadding)
        .height(this.boardSize + 2 * this.boardPadding)
        .fill('#DEB887')
        .radius(8)

      Canvas(this.canvascontext)
        .width(this.boardSize + 2 * this.boardPadding)
        .height(this.boardSize + 2 * this.boardPadding)
        .onReady(() => {
          this.onDrawGrid(this.canvascontext)
        })
        .onClick((event: ClickEvent) => {
          this.handleClick(event)
        })

      ForEach(this.gameState.getBoard(), (row: number[], rowIndex: number) => {
        ForEach(row, (cell: number, colIndex: number) => {
          if (cell !== 0) {
            Circle()
              .fill(cell === 1 ? '#000000' : '#FFFFFF')
              .stroke(cell === 1 ? '#000000' : '#CCCCCC')
              .strokeWidth(1)
              .width(this.cellSize * 0.9)
              .height(this.cellSize * 0.9)
              .position({
                x: this.boardPadding + colIndex * this.cellSize - this.cellSize * 0.45,
                y: this.boardPadding + rowIndex * this.cellSize - this.cellSize * 0.45
              })
          }
        }, (colIndex: number) => colIndex.toString())
      }, (rowIndex: number) => rowIndex.toString())

      if (this.showGameOverDialog) {
        Column() {
          Text(this.winnerText)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 20 })

          Button('重新开始')
            .width(120)
            .height(40)
            .backgroundColor('#007DFF')
            .onClick(() => this.restartGame())
        }
        .width(260)
        .height(150)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .justifyContent(FlexAlign.Center)
        .position({
          x: (this.boardSize + 2 * this.boardPadding) / 2 - 130,
          y: (this.boardSize + 2 * this.boardPadding) / 2 - 75
        })
      }
    }
    .width(this.boardSize + 2 * this.boardPadding)
    .height(this.boardSize + 2 * this.boardPadding)
  }

  private onDrawGrid(ctx: CanvasRenderingContext2D): void {
    const size: number = this.gameState.getBoardSize()

    ctx.strokeStyle = '#000000'
    ctx.lineWidth = 1

    for (let i: number = 0; i < size; i++) {
      const y: number = this.boardPadding + i * this.cellSize
      ctx.beginPath()
      ctx.moveTo(this.boardPadding, y)
      ctx.lineTo(this.boardPadding + (size - 1) * this.cellSize, y)
      ctx.closePath()
      ctx.stroke()
    }

    for (let i: number = 0; i < size; i++) {
      const x: number = this.boardPadding + i * this.cellSize
      ctx.beginPath()
      ctx.moveTo(x, this.boardPadding)
      ctx.lineTo(x, this.boardPadding + (size - 1) * this.cellSize)
      ctx.closePath()
      ctx.stroke()
    }

    const starPoints: number[] = [3, 9, 15]
    ctx.fillStyle = '#000000'

    for (const i of starPoints) {
      for (const j of starPoints) {
        const x: number = this.boardPadding + i * this.cellSize
        const y: number = this.boardPadding + j * this.cellSize
        ctx.beginPath()
        ctx.arc(x, y, 3, 0, Math.PI * 2)
        ctx.closePath()
        ctx.fill()
      }
    }
  }
}