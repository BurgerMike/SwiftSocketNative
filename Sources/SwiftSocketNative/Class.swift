//
//  Class.swift
//  SwiftSocketNative
//
//  Created by Miguel Carlos Elizondo Martinez on 15/05/25.
//

import Foundation

public final class SwiftSocketIOClient: SocketClient {
    // MARK: - Estado y configuración
    private let url: URL
    private let path: String
    private let namespace: String
    private let auth: [String: String]
    
    private(set) var isConnected: Bool = false
    private var webSocket: URLSessionWebSocketTask?
    private let session: URLSession = .shared
    private let queue = DispatchQueue(label: "SwiftSocketIOClientQueue", attributes: .concurrent)
    
    private var systemListeners: [String: [(Any) -> Void]] = [:]
    private var eventListeners: [String: [(Any) -> Void]] = [:]
    
    private let ackManager = AckManager()
    private var ackCounter: Int = 0
    
    // MARK: - Inicialización
    public init(
        url: URL,
        path: String = "/socket.io",
        namespace: String = "/",
        auth: [String: String] = [:]
    ) {
        self.url = url
        self.path = path
        self.namespace = namespace
        self.auth = auth
    }
    
    public func connect() {
        guard webSocket == nil else {
            notifySystem(event: "connect_skipped", data: "Ya hay conexión activa.")
            return
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.path = path
        components.queryItems = auth.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let finalURL = components.url else {
            notifySystem(event: "error", data: SocketError.webSocketUnavailable)
            return
        }
        
        webSocket = session.webSocketTask(with: finalURL)
        webSocket?.resume()
        listen()
    }
    
    private func listen() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handle(message)
            case .failure(let error):
                self?.notifySystem(event: "connect_error", data: error)
            }
            
            self?.listen() // sigue escuchando
        }
    }
    
    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            notifySystem(event: "message", data: text)
        case .data(let data):
            notifySystem(event: "data", data: data)
        @unknown default:
            notifySystem(event: "error", data: SocketError.custom("Tipo de mensaje desconocido"))
        }
    }
    
    public func emit<T: Encodable>(
        event: String,
        data: T?,
        ack: ((Result<Void, SocketError>) -> Void)? = nil
    ) {
        guard isConnected else {
            ack?(.failure(.notConnected))
            return
        }
        
        let id = nextAckId()
        if let ack = ack {
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
            recipientId: nil
        )
        
        guard let json = try? JSONEncoder().encode(eventPayload),
              let text = String(data: json, encoding: .utf8)
        else {
            ack?(.failure(.encodingFailed))
            return
        }
        
        webSocket?.send(.string(text)) { error in
            if let error = error {
                self.notifySystem(event: "error", data: error)
                ack?(.failure(.custom(error.localizedDescription)))
            }
        }
    }
    
    private func nextAckId() -> String {
        ackCounter += 1
        return "\(ackCounter)"
    }
    
    public func on(event: String, callback: @escaping (Any) -> Void) {
        eventListeners[event, default: []].append(callback)
    }

    public func onSystem(event: String, callback: @escaping (Any) -> Void) {
        systemListeners[event, default: []].append(callback)
    }

    private func notifySystem(event: String, data: Any) {
        systemListeners[event]?.forEach { $0(data) }
    }

    public func off(event: String) {
        eventListeners[event] = []
    }

    public func disconnect() {
        ackManager.cancelAll()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
        notifySystem(event: "disconnect", data: "Socket cerrado.")
    }
}
