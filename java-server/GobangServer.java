import com.sun.net.httpserver.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

public class GobangServer {

    static class Room {
        int playerCount = 0;
        List<Move> moves = new CopyOnWriteArrayList<>(); // 修复 << 为 <
        boolean started = false;
    }

    static class Move {
        int player, row, col;
        String type;

        Move(int p, String t, int r, int c) {
            player = p;
            type = t;
            row = r;
            col = c;
        }
    }

    static Map<String, Room> rooms = new ConcurrentHashMap<>();
    static Random rand = new Random();

    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        server.createContext("/create", new CreateHandler());
        server.createContext("/join", new JoinHandler());
        server.createContext("/move", new MoveHandler());
        server.createContext("/poll", new PollHandler());
        server.setExecutor(Executors.newCachedThreadPool());
        server.start();

        System.out.println("========================================");
        System.out.println("围棋服务器已启动，端口: 8080");
        System.out.println("监听地址: 0.0.0.0:8080 (所有网卡)");
        System.out.println("========================================");

        Enumeration<NetworkInterface> nets = NetworkInterface.getNetworkInterfaces(); // 修复 <<
        System.out.println("本机可用IP地址:");
        for (NetworkInterface netint : Collections.list(nets)) {
            if (!netint.isUp() || netint.isLoopback()) continue;
            Enumeration<InetAddress> inetAddresses = netint.getInetAddresses(); // 修复 <<
            for (InetAddress inetAddress : Collections.list(inetAddresses)) {
                if (inetAddress instanceof Inet4Address) {
                    System.out.println("  " + inetAddress.getHostAddress());
                }
            }
        }
        System.out.println("========================================");
    }

    static String readBody(HttpExchange ex) throws IOException {
        InputStream is = ex.getRequestBody();
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] buf = new byte[1024];
        int n;
        while ((n = is.read(buf)) != -1) baos.write(buf, 0, n);
        return baos.toString(StandardCharsets.UTF_8.name());
    }

    static void sendJson(HttpExchange ex, int code, String json) throws IOException {
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", "application/json; charset=UTF-8");
        ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
        ex.getResponseHeaders().set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type");
        ex.sendResponseHeaders(code, bytes.length);
        try (OutputStream os = ex.getResponseBody()) {
            os.write(bytes);
        }
        ex.close();
    }

    static String json(String... pairs) {
        StringBuilder sb = new StringBuilder("{");
        for (int i = 0; i < pairs.length; i += 2) {
            if (i > 0) sb.append(",");
            sb.append("\"").append(pairs[i]).append("\":");
            String v = pairs[i+1];
            if (v.startsWith("[") || v.startsWith("{")) {
                sb.append(v);
            } else {
                sb.append("\"").append(v).append("\"");
            }
        }
        sb.append("}");
        return sb.toString();
    }

    static String getField(String json, String key) {
        String p = "\"" + key + "\"\\s*:\\s*\"?([^\",\\}]*)\"?";
        java.util.regex.Matcher m = java.util.regex.Pattern.compile(p).matcher(json);
        return m.find() ? m.group(1).trim() : "";
    }

    static String getQuery(String q, String key) {
        if (q == null) return "";
        String p = key + "=([^&]*)";
        java.util.regex.Matcher m = java.util.regex.Pattern.compile(p).matcher(q);
        return m.find() ? m.group(1).trim() : "";
    }

    static class CreateHandler implements HttpHandler {
        public void handle(HttpExchange ex) throws IOException {
            System.out.println("[CREATE] 请求来自: " + ex.getRemoteAddress());

            if ("OPTIONS".equals(ex.getRequestMethod())) {
                sendJson(ex, 200, json("success", "true"));
                return;
            }
            String roomId = String.format("%04d", rand.nextInt(10000));
            Room r = new Room();
            r.playerCount = 1;
            rooms.put(roomId, r);
            System.out.println("[CREATE] 创建房间: " + roomId);
            sendJson(ex, 200, json("roomId", roomId, "player", "1", "success", "true"));
        }
    }

    static class JoinHandler implements HttpHandler {
        public void handle(HttpExchange ex) throws IOException {
            System.out.println("[JOIN] 请求来自: " + ex.getRemoteAddress());

            if ("OPTIONS".equals(ex.getRequestMethod())) {
                sendJson(ex, 200, json("success", "true"));
                return;
            }
            String body = readBody(ex);
            System.out.println("[JOIN] 请求体: " + body);

            String roomId = getField(body, "roomId");
            System.out.println("[JOIN] 房间号: " + roomId);

            Room r = rooms.get(roomId);
            if (r == null) {
                System.out.println("[JOIN] 房间不存在: " + roomId);
                sendJson(ex, 200, json("success", "false", "msg", "房间不存在"));
                return;
            }
            if (r.playerCount >= 2) {
                System.out.println("[JOIN] 房间已满: " + roomId);
                sendJson(ex, 200, json("success", "false", "msg", "房间已满"));
                return;
            }
            r.playerCount = 2;
            r.started = true;
            System.out.println("[JOIN] 加入成功: " + roomId + ", player=2");
            sendJson(ex, 200, json("success", "true", "player", "2"));
        }
    }

    static class MoveHandler implements HttpHandler {
        public void handle(HttpExchange ex) throws IOException {
            System.out.println("[MOVE] 请求来自: " + ex.getRemoteAddress());

            if ("OPTIONS".equals(ex.getRequestMethod())) {
                sendJson(ex, 200, json("success", "true"));
                return;
            }
            try {
                String body = readBody(ex);
                System.out.println("[MOVE] 请求体: " + body);

                String roomId = getField(body, "roomId");
                int player = Integer.parseInt(getField(body, "player"));
                String type = getField(body, "type");

                Room r = rooms.get(roomId);
                if (r != null) {
                    if ("pass".equals(type)) {
                        r.moves.add(new Move(player, "pass", -1, -1));
                        System.out.println("[MOVE] Pass: player=" + player);
                    } else {
                        String rowStr = getField(body, "row");
                        String colStr = getField(body, "col");
                        if (rowStr.isEmpty() || colStr.isEmpty()) {
                            System.out.println("[MOVE] 错误: row或col为空");
                            sendJson(ex, 200, json("success", "false", "msg", "row/col不能为空"));
                            return;
                        }
                        int row = Integer.parseInt(rowStr);
                        int col = Integer.parseInt(colStr);
                        r.moves.add(new Move(player, "move", row, col));
                        System.out.println("[MOVE] Move: player=" + player + ", row=" + row + ", col=" + col);
                    }
                }
                sendJson(ex, 200, json("success", "true"));
            } catch (Exception e) {
                System.out.println("[MOVE] 错误: " + e.getMessage());
                e.printStackTrace();
                sendJson(ex, 200, json("success", "false", "msg", "参数错误: " + e.getMessage()));
            }
        }
    }

    static class PollHandler implements HttpHandler {
        public void handle(HttpExchange ex) throws IOException {
            try {
                String q = ex.getRequestURI().getQuery();
                String roomId = getQuery(q, "roomId");
                String playerStr = getQuery(q, "player");
                String lastStr = getQuery(q, "lastIndex");

                int player = playerStr.isEmpty() ? 0 : Integer.parseInt(playerStr);
                int last = lastStr.isEmpty() ? 0 : Integer.parseInt(lastStr);

                Room r = rooms.get(roomId);
                StringBuilder arr = new StringBuilder("[");
                if (r != null) {
                    for (int i = last; i < r.moves.size(); i++) {
                        if (i > last) arr.append(",");
                        Move m = r.moves.get(i);
                        arr.append("{\"player\":").append(m.player)
                           .append(",\"type\":\"").append(m.type).append("\"")
                           .append(",\"row\":").append(m.row)
                           .append(",\"col\":").append(m.col).append("}");
                    }
                }
                arr.append("]");
                boolean started = r != null && r.started;
                sendJson(ex, 200, json("moves", arr.toString(), "started", started ? "true" : "false"));
            } catch (Exception e) {
                e.printStackTrace();
                sendJson(ex, 200, json("moves", "[]", "started", "false"));
            }
        }
    }
}