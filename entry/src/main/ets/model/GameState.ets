/**
 * 玩家枚举
 */
export enum Player {
  EMPTY = 0,
  BLACK = 1,
  WHITE = 2
}

// 定义位置接口（解决ArkTS匿名对象报错）
export interface Pos {
  row: number;
  col: number;
}

export class GameState {
  private board: Array<Array<number>> = [];
  private currentPlayer: Player = Player.BLACK;
  private readonly boardSize: number = 19;
  private lastMoveRow: number = -1;
  private lastMoveCol: number = -1;
  private passCount: number = 0;
  private gameOver: boolean = false;
  private blackScore: number = 0;
  private whiteScore: number = 0;

  constructor() {
    this.initBoard();
  }

  private initBoard(): void {
    this.board = [];
    for (let i = 0; i < this.boardSize; i++) {
      const row: Array<number> = [];
      for (let j = 0; j < this.boardSize; j++) {
        row.push(Player.EMPTY);
      }
      this.board.push(row);
    }
    this.currentPlayer = Player.BLACK;
    this.lastMoveRow = -1;
    this.lastMoveCol = -1;
    this.passCount = 0;
    this.gameOver = false;
    this.blackScore = 0;
    this.whiteScore = 0;
  }

  getBoard(): Array<Array<number>> { return this.board; }
  getBoardSize(): number { return this.boardSize; }
  getCurrentPlayer(): Player { return this.currentPlayer; }
  isGameOver(): boolean { return this.gameOver; }
  getLastMoveRow(): number { return this.lastMoveRow; }
  getLastMoveCol(): number { return this.lastMoveCol; }
  getBlackScore(): number { return this.blackScore; }
  getWhiteScore(): number { return this.whiteScore; }

  // 落子（围棋规则）
  makeMove(row: number, col: number): boolean {
    if (this.gameOver || row < 0 || row >= this.boardSize || col < 0 || col >= this.boardSize) {
      return false;
    }
    if (this.board[row][col] !== Player.EMPTY) {
      return false;
    }

    // 试落子，检查是否合法（不自杀）
    this.board[row][col] = this.currentPlayer;
    const captured: Pos[] = this.findCaptured(row, col);

    // 如果落子后自己没气且没提对方子 = 自杀，非法
    if (captured.length === 0 && !this.hasLiberty(row, col)) {
      this.board[row][col] = Player.EMPTY;
      return false;
    }

    // 提子
    for (let pos of captured) {
      this.board[pos.row][pos.col] = Player.EMPTY;
      if (this.currentPlayer === Player.BLACK) {
        this.blackScore++;
      } else {
        this.whiteScore++;
      }
    }

    this.lastMoveRow = row;
    this.lastMoveCol = col;
    this.passCount = 0;
    this.currentPlayer = this.currentPlayer === Player.BLACK ? Player.WHITE : Player.BLACK;
    return true;
  }

  // Pass（虚手）
  pass(): void {
    this.passCount++;
    this.lastMoveRow = -1;
    this.lastMoveCol = -1;
    if (this.passCount >= 2) {
      this.gameOver = true;
    }
    this.currentPlayer = this.currentPlayer === Player.BLACK ? Player.WHITE : Player.BLACK;
  }

  // 找被提掉的子
  private findCaptured(row: number, col: number): Pos[] {
    const opponent: Player = this.currentPlayer === Player.BLACK ? Player.WHITE : Player.BLACK;
    const captured: Pos[] = [];
    const visited: Array<Array<boolean>> = Array(this.boardSize).fill(false).map(() => Array(this.boardSize).fill(false));

    // 检查对手相邻棋块
    const dirs: number[][] = [[1,0], [-1,0], [0,1], [0,-1]];
    for (let d of dirs) {
      const nr = row + d[0];
      const nc = col + d[1];
      if (nr >= 0 && nr < this.boardSize && nc >= 0 && nc < this.boardSize
        && this.board[nr][nc] === opponent && !visited[nr][nc]) {
        const group: Pos[] = this.getGroup(nr, nc, visited);
        if (!this.groupHasLiberty(group)) {
          captured.push(...group);
        }
      }
    }
    return captured;
  }

  // 获取连通块
  private getGroup(row: number, col: number, visited: Array<Array<boolean>>): Pos[] {
    const color: number = this.board[row][col];
    const group: Pos[] = [];
    const stack: Pos[] = [{row, col}];
    visited[row][col] = true;

    while (stack.length > 0) {
      const cur = stack.pop()!;
      group.push(cur);
      const dirs: number[][] = [[1,0], [-1,0], [0,1], [0,-1]];
      for (let d of dirs) {
        const nr = cur.row + d[0];
        const nc = cur.col + d[1];
        if (nr >= 0 && nr < this.boardSize && nc >= 0 && nc < this.boardSize
          && !visited[nr][nc] && this.board[nr][nc] === color) {
          visited[nr][nc] = true;
          stack.push({row: nr, col: nc});
        }
      }
    }
    return group;
  }

  // 棋块是否有气
  private groupHasLiberty(group: Pos[]): boolean {
    const dirs: number[][] = [[1,0], [-1,0], [0,1], [0,-1]];
    for (let stone of group) {
      for (let d of dirs) {
        const nr = stone.row + d[0];
        const nc = stone.col + d[1];
        if (nr >= 0 && nr < this.boardSize && nc >= 0 && nc < this.boardSize
          && this.board[nr][nc] === Player.EMPTY) {
          return true;
        }
      }
    }
    return false;
  }

  // 单个棋子是否有气
  private hasLiberty(row: number, col: number): boolean {
    const visited: Array<Array<boolean>> = Array(this.boardSize).fill(false).map(() => Array(this.boardSize).fill(false));
    const group: Pos[] = this.getGroup(row, col, visited);
    return this.groupHasLiberty(group);
  }

  restart(): void {
    this.initBoard();
  }
}