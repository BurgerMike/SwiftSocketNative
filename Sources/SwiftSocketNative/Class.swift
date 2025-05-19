//
//  Class.swift
//  SwiftSocketNative
//
//  Created by Miguel Carlos Elizondo Martinez on 15/05/25.
//

import Foundation
import SwiftUI

// MARK: - Protocolo base para el cliente tipo Engine.IO


public final class SwiftSocketIOClient: SocketClient {
    // MARK: - Estado y configuración
    private let url: URL
    private let path: String
    private let namespace: String
    private let auth: [String: String]
    private let isTestMode: Bool
    
    private var reconnectStrategy: ReconnectStrategy?
    private var middleware: [SocketMiddleware] = []
    private var logger: SocketLogger?
    private var storage: SocketStorage?
    
    private(set) var isConnected: Bool = false
    private(set) public var socketID: String?
    private let queue = DispatchQueue(label: "SwiftSocketIOClientQueue", attributes: .concurrent)

    private var anyListeners: [(String, Any) -> Void] = []
    private var systemListeners: [String: [(Any) -> Void]] = [:]
    private var eventListeners: [String: [(id: UUID, callback: (Any) -> Void)]] = [:]
    private var onceListeners: [String: [(Any) -> Void]] = [:]
    
    private let ackManager = AckManager()
    private var ackCounter: Int = 0
    
    private var engineIO: EngineIOClient = URLSessionEngineIOClient()
    
    // MARK: - Inicialización
    public init(
        url: URL,
        path: String = "/socket.io",
        namespace: String = "/",
        auth: [String: String] = [:],
        isTestMode: Bool = false,
        reconnectStrategy: ReconnectStrategy? = nil,
        middleware: [SocketMiddleware] = [],
        logger: SocketLogger? = nil,
        storage: SocketStorage? = nil
    ) {
        self.url = url
        self.path = path
        self.namespace = namespace
        self.auth = auth
        self.isTestMode = isTestMode
        self.reconnectStrategy = reconnectStrategy
        self.middleware = middleware
        self.logger = logger
        self.storage = storage
    }
    
    public func connect() {
        guard !isTestMode else {
            print("🧪 Modo prueba activado: no se establecerá conexión real.")
            notifySystem(event: "connect_test_mode", data: "Modo prueba activado.")
            return
        }
        guard !isConnected else {
            notifySystem(event: "connect_skipped", data: "Ya hay conexión activa.")
            return
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            notifySystem(event: "error", data: SocketError.webSocketUnavailable)
            return
        }
        components.scheme = url.scheme == "http" ? "ws" : (url.scheme == "https" ? "wss" : url.scheme)
        components.path = path
        components.queryItems = auth.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let finalURL = components.url else {
            notifySystem(event: "error", data: SocketError.webSocketUnavailable)
            return
        }
        engineIO.connect(url: finalURL, path: path, auth: auth)
        isConnected = true
        notifySystem(event: "connect_started", data: "Iniciando conexión personalizada.")
        startListening()
    }
    
    // private func listen() {
    //     // Aquí va la lógica para escuchar mensajes con el cliente personalizado
    // }
    
    // private func handle(_ message: Any) {
    //     // Aquí va la lógica para manejar mensajes recibidos con el cliente personalizado
    // }
    
    public func emit<T: Encodable>(
        event: String,
        data: T?,
        ack: ((Result<Void, SocketError>) -> Void)? = nil
    ) {
        guard isConnected else {
            ack?(.failure(.notConnected))
            return
        }

        let id = ack != nil ? nextAckId() : nil

        if let ack = ack, let id = id {
            ackManager.addAck(id: id, timeout: 5, callback: { result in
                switch result {
                case .success: ack(.success(()))
                case .failure(let error): ack(.failure(error))
                }
            })
        }

        let eventPayload = OutgoingMessage(
            event: event,
            payloadObject: data,
            recipientId: nil,
            metadata: nil,
            ackId: id
        )
        
        storage?.storeOutgoingMessage(eventPayload)

        guard let json = try? JSONEncoder().encode(eventPayload),
              let text = String(data: json, encoding: .utf8)
        else {
            ack?(.failure(.encodingFailed))
            return
        }

        if isTestMode {
            print("🧪 Emitiendo mensaje en modo prueba: \(text)")
        }

        engineIO.send(message: text)
    }
    
    private func nextAckId() -> String {
        ackCounter += 1
        return "\(ackCounter)"
    }
    
    @discardableResult
    public func on(event: String, callback: @escaping (Any) -> Void) -> UUID {
        let id = UUID()
        eventListeners[event, default: []].append((id: id, callback: callback))
        return id
    }
    
    public func on<T: Decodable>(
        event: String,
        decodeTo type: T.Type,
        callback: @escaping (T) -> Void
    ) {
        on(event: event) { raw in
            if let dict = raw as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: dict),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                callback(decoded)
            }
        }
    }
    
    public func once(event: String, callback: @escaping (Any) -> Void) {
        onceListeners[event, default: []].append(callback)
    }

    public func onAny(callback: @escaping (String, Any) -> Void) {
        anyListeners.append(callback)
    }
    
    public func onSystem(event: String, callback: @escaping (Any) -> Void) {
        systemListeners[event, default: []].append(callback)
    }
    
    public func offSystem(event: String) {
        systemListeners[event] = []
    }
    
    public func offAll() {
        eventListeners.removeAll()
    }
    
    public func offAllSystem() {
        systemListeners.removeAll()
    }
    
    private func notifySystem(event: String, data: Any) {
        systemListeners[event]?.forEach { $0(data) }
    }
    
    public func off(event: String) {
        eventListeners[event] = []
    }
    
    public func off(event: String, callbackId: UUID) {
        eventListeners[event]?.removeAll { $0.id == callbackId }
    }
    
    public func disconnect() {
        ackManager.cancelAll()
        engineIO.disconnect()
        isConnected = false
        notifySystem(event: "disconnect", data: "Socket cerrado.")
    }
    
    private func startListening() {
        engineIO.listen { [weak self] message in
            guard let self = self else { return }
            // Intentamos decodificar el mensaje
            guard let data = message.data(using: .utf8) else {
                self.notifySystem(event: "error", data: SocketError.decodingFailed)
                return
            }

            struct IncomingMessage: Decodable {
                let event: String
                let data: AnyCodable
                let ackId: String?
                let socketId: String?
            }

            do {
                let incoming = try JSONDecoder().decode(IncomingMessage.self, from: data)

                if let ackId = incoming.ackId {
                    self.ackManager.resolveAck(id: ackId, with: incoming.data.value)
                }
                if let sid = incoming.socketId {
                    self.socketID = sid
                }

                let reduced = self.middleware.reduce((incoming.event, incoming.data.value)) { result, mw in
                    mw.process(event: result.0, data: result.1) ?? result
                }
                
                guard let processed = Optional(reduced) else {
                    self.logger?.log(event: "middleware_blocked", data: incoming.event)
                    return
                }
                let finalEvent = processed.0
                let finalData = processed.1

                self.eventListeners[finalEvent]?.forEach { $0.callback(finalData) }
                if let onceList = self.onceListeners[finalEvent] {
                    onceList.forEach { $0(finalData) }
                    self.onceListeners[finalEvent] = nil
                }
                self.anyListeners.forEach { $0(finalEvent, finalData) }

            } catch {
                self.notifySystem(event: "error", data: SocketError.decodingFailed)
            }
        }
    }
    
    // MARK: - Finalización del cliente
    public func finalize() {
        disconnect()
        offAll()
        offAllSystem()
        isConnected = false
        print("🧹 Cliente limpiado y listo para pruebas o reinicio.")
    }
}

final class URLSessionEngineIOClient: EngineIOClient {
    private var socket: URLSessionWebSocketTask?
    private let session: URLSession = .shared
    
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 3
    private var pingTimer: Timer?
    private var lastPong: Date = Date()
    
    private var currentURL: URL?
    private var currentPath: String = ""
    private var currentAuth: [String: String] = [:]

    func connect(url: URL, path: String, auth: [String: String]) {
        currentURL = url
        currentPath = path
        currentAuth = auth
        
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("❌ URL inválida para conexión WebSocket")
            return
        }
        components.queryItems = auth.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let finalURL = components.url else {
            print("❌ URL inválida para conexión WebSocket")
            return
        }

        socket = session.webSocketTask(with: finalURL)
        socket?.resume()

        // Emite evento de intento de conexión
        print("🔄 Intentando conectar a \(finalURL)")
        SwiftSocketIOClient.sharedNotifySystem(event: "reconnect_attempt", data: reconnectAttempts)
        reconnectAttempts = 0
        startPing()
    }

    func send(message: String) {
        socket?.send(.string(message)) { error in
            if let error = error {
                print("❌ Error al enviar mensaje:", error)
            }
        }
    }

        func listen(onMessage: @escaping (String) -> Void) {
            socket?.receive { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    self.reconnectAttempts = 0 // ✅ Reset de intentos en caso de éxito
                    switch message {
                    case .string(let text):
                        onMessage(text)
                    case .data(let data):
                        if let string = String(data: data, encoding: .utf8) {
                            onMessage(string)
                        } else {
                            print("⚠️ Mensaje binario no interpretable")
                        }
                    default:
                        break
                    }
                    self.listen(onMessage: onMessage) // 🔁 continuar normalmente

                case .failure(let error):
                    if self.reconnectAttempts < self.maxReconnectAttempts {
                        if self.reconnectAttempts == 0 {
                            print("❌ Error al recibir mensaje: \(error.localizedDescription)")
                            SwiftSocketIOClient.sharedNotifySystem(event: "connect_error", data: error.localizedDescription)
                        }
                        self.reconnectAttempts += 1
                        print("🔁 Reintentando conexión en \(self.reconnectDelay)s... (\(self.reconnectAttempts))")
                        SwiftSocketIOClient.sharedNotifySystem(event: "reconnect_attempt", data: self.reconnectAttempts)

                        DispatchQueue.main.asyncAfter(deadline: .now() + self.reconnectDelay) {
                            self.listen(onMessage: onMessage)
                        }
                    } else {
                        let errorMessage = "❌ Falló reconexión después de \(self.reconnectAttempts) intentos."
                        SwiftSocketIOClient.sharedNotifySystem(event: "reconnect_failed", data: errorMessage)
                        print(errorMessage)
                    }
                }
            }
        }

    func disconnect() {
        stopPing()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }
    
    private func startPing() {
        stopPing()
        lastPong = Date() // Resetea la marca de tiempo antes del siguiente ping
        pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendPing() {
        guard let socket = socket else { return }
        lastPong = Date()
        socket.sendPing { error in
            if let error = error {
                print("❌ Ping error:", error)
                SwiftSocketIOClient.sharedNotifySystem(event: "connect_timeout", data: error.localizedDescription)
            } else {
                print("📡 Ping enviado")
                SwiftSocketIOClient.sharedNotifySystem(event: "ping", data: Date())
            }
        }
    }
}

// MARK: - AnyCodable para decodificación dinámica
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Tipo no soportado")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let string as String:
            try container.encode(string)
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: container.codingPath, debugDescription: "Tipo no soportado"))
        }
    }
}

extension SwiftSocketIOClient {
    static func sharedNotifySystem(event: String, data: Any) {
        // Notificación global si el socket está en uso
        NotificationCenter.default.post(name: .socketSystemEvent, object: nil, userInfo: ["event": event, "data": data])
    }
}

extension Notification.Name {
    static let socketSystemEvent = Notification.Name("socketSystemEvent")
}

public func onAny(callback: @escaping (String, Any) -> Void) {
    // Se asume instancia singleton o de uso global, o bien acceso a instancia.
    // Aquí se muestra cómo agregarlo a la instancia global si existiera.
    // Si es una función global, debe acceder a la instancia correspondiente.
    // Por ejemplo, si tienes una instancia compartida:
    // SwiftSocketIOClient.shared.anyListeners.append(callback)
    // Pero aquí, como ejemplo, se deja como comentario.
    // Implementación típica:
    // (esto requiere acceso a la instancia del cliente, que no está definida aquí)
    // client.anyListeners.append(callback)
}
