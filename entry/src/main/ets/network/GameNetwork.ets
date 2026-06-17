import http from '@ohos.net.http';

export interface NetMessage {
  type: string;  // 'move' | 'pass' | 'win'
  row?: number;
  col?: number;
  winner?: number;
  player?: number;
}

interface CreateResponse {
  roomId: string;
  player: string;
  success: string;
}

interface JoinResponse {
  success: string;
  player: number;
  msg?: string;
}

interface MoveData {
  player: number;
  row: number;
  col: number;
}

interface PollResponse {
  moves: MoveData[];
  started: boolean;
}

export class GameNetwork {
  private serverUrl: string = '';
  private roomId: string = '';
  private myPlayer: number = 0;
  private lastIndex: number = 0;
  private pollTimer: number = -1;
  private dataHandler: (data: NetMessage) => void = () => {};

  setOnData(callback: (data: NetMessage) => void): void {
    this.dataHandler = callback;
  }

  setServerUrl(url: string): void {
    this.serverUrl = url.replace(/\/$/, '');
  }

  async createRoom(): Promise<string> {
    let req = http.createHttp();
    let resp = await req.request(`${this.serverUrl}/create`, {
      method: http.RequestMethod.POST
    });
    let obj: CreateResponse = JSON.parse(resp.result.toString()) as CreateResponse;
    this.roomId = obj.roomId;
    this.myPlayer = 1;
    this.startPolling();
    return this.roomId;
  }

  async joinRoom(roomId: string): Promise<boolean> {
    let req = http.createHttp();
    let resp = await req.request(`${this.serverUrl}/join`, {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: JSON.stringify({ roomId })
    });
    let obj: JoinResponse = JSON.parse(resp.result.toString()) as JoinResponse;
    if (obj.success === 'true') {
      this.roomId = roomId;
      this.myPlayer = obj.player;
      this.startPolling();
      return true;
    }
    return false;
  }

  send(data: NetMessage): void {
    if (!this.roomId) return;
    let req = http.createHttp();
    req.request(`${this.serverUrl}/move`, {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: JSON.stringify({
        roomId: this.roomId,
        player: this.myPlayer,
        row: data.row,
        col: data.col
      })
    });
  }

  private startPolling(): void {
    this.pollTimer = setInterval(() => this.doPoll(), 500);
  }

  private async doPoll(): Promise<void> {
    let req = http.createHttp();
    try {
      let url = `${this.serverUrl}/poll?roomId=${this.roomId}&player=${this.myPlayer}&lastIndex=${this.lastIndex}`;
      let resp = await req.request(url, { method: http.RequestMethod.GET });
      let obj: PollResponse = JSON.parse(resp.result.toString()) as PollResponse;
      if (obj.moves && Array.isArray(obj.moves)) {
        for (let m of obj.moves) {
          this.lastIndex++;
          if (m.player !== this.myPlayer) {
            this.dataHandler({ type: 'move', row: m.row, col: m.col, player: m.player });
          }
        }
      }
    } catch (e) {
      console.error('轮询失败', e);
    }
  }

  close(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  getRoomId(): string { return this.roomId; }
  getMyPlayer(): number { return this.myPlayer; }
}