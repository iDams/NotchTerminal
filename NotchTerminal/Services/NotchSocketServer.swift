import Foundation
import os.log

private let logger = Logger(subsystem: "com.maomao.NotchTerminal", category: "SocketServer")

public struct NotchIPCEvent: Codable {
    public let tool: String?
    public let status: String?
    public let message: String?
    public let progress: Double?
    public let icon: String?
    public let displayID: UInt32?
    public let terminalNumber: Int?
}

typealias NotchIPCEventHandler = @Sendable (NotchIPCEvent) -> Void

final class NotchSocketServer {
    static let shared = NotchSocketServer()
    static let socketPath = "/tmp/notchterminal.sock"

    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var eventHandler: NotchIPCEventHandler?
    private let queue = DispatchQueue(label: "com.maomao.NotchTerminal.socket", qos: .userInitiated)

    private init() {}

    func start(onEvent: @escaping NotchIPCEventHandler) {
        queue.async { [weak self] in
            self?.startServer(onEvent: onEvent)
        }
    }

    private func startServer(onEvent: @escaping NotchIPCEventHandler) {
        guard serverSocket < 0 else { return }

        eventHandler = onEvent

        unlink(Self.socketPath)

        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            logger.error("Failed to create socket: \(errno)")
            return
        }

        let flags = fcntl(serverSocket, F_GETFL)
        _ = fcntl(serverSocket, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        Self.socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let pathBufferPtr = UnsafeMutableRawPointer(pathPtr)
                    .assumingMemoryBound(to: CChar.self)
                strcpy(pathBufferPtr, ptr)
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            logger.error("Failed to bind socket: \(errno)")
            close(serverSocket)
            serverSocket = -1
            return
        }

        chmod(Self.socketPath, 0o777)

        guard listen(serverSocket, 10) == 0 else {
            logger.error("Failed to listen: \(errno)")
            close(serverSocket)
            serverSocket = -1
            return
        }

        logger.info("Listening on \(Self.socketPath, privacy: .public)")

        acceptSource = DispatchSource.makeReadSource(fileDescriptor: serverSocket, queue: queue)
        acceptSource?.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        acceptSource?.setCancelHandler { [weak self] in
            if let fd = self?.serverSocket, fd >= 0 {
                close(fd)
                self?.serverSocket = -1
            }
        }
        acceptSource?.resume()
    }

    func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        unlink(Self.socketPath)
        
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    private func acceptConnection() {
        let clientSocket = accept(serverSocket, nil, nil)
        guard clientSocket >= 0 else { return }

        var nosigpipe: Int32 = 1
        setsockopt(clientSocket, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout<Int32>.size))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.handleClient(clientSocket)
        }
    }

    private func handleClient(_ clientSocket: Int32) {
        defer { close(clientSocket) }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        let data = Data(buffer[0..<bytesRead])

        guard let event = try? JSONDecoder().decode(NotchIPCEvent.self, from: data) else {
            logger.warning("Failed to parse IPC event")
            return
        }

        logger.info("Received IPC Event: \(String(describing: event.tool)) - \(String(describing: event.status))")
        eventHandler?(event)
    }
}
