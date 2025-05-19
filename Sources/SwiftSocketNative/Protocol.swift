//
//  Protocol.swift
//  SwiftSocket.ioNative
//
//  Created by Miguel Carlos Elizondo Martinez on 14/05/25.
//
import Foundation

// MARK: - Protocolos

/// Protocolo base para un cliente de sockets nativo en Swift.
public protocol SocketClient {
    /// Identificador único del socket asignado por el servidor.
    var socketID: String? { get }

    /// Inicia la conexión con el servidor.
    func connect()

    /// Cierra la conexión actual.
    func disconnect()

    /// Envía un evento con datos opcionales y maneja respuesta ACK si aplica.
    func emit<T: Encodable>(event: String, data: T?, ack: ((Result<Void, SocketError>) -> Void)?)

    /// Escucha un evento personalizado del servidor.
    @discardableResult
    func on(event: String, callback: @escaping (Any) -> Void) -> UUID

    /// Escucha un evento y decodifica automáticamente su contenido a un tipo concreto.
    func on<T: Decodable>(event: String, decodeTo type: T.Type, callback: @escaping (T) -> Void)

    /// Escucha eventos del sistema interno como conexión, errores, etc.
    func onSystem(event: String, callback: @escaping (Any) -> Void)

    /// Escucha cualquier evento recibido, sin importar su nombre.
    func onAny(callback: @escaping (String, Any) -> Void)

    /// Escucha un evento una sola vez.
    func once(event: String, callback: @escaping (Any) -> Void)

    /// Elimina todos los listeners de un evento.
    func off(event: String)

    /// Elimina un listener específico identificado por UUID.
    func off(event: String, callbackId: UUID)
}

public protocol SocketEventRepresentable {
    var event: String { get }
    var payload: Data? { get }
    var namespace: String? { get }
}


public protocol AckHandler {
    func addAck(id: String, timeout: TimeInterval, callback: @escaping (Result<Any?, SocketError>) -> Void)
    func resolveAck(id: String, with data: Any?)
    func failAck(id: String, error: SocketError)
    func cancelAll()
}

/// Protocolo que representa un mensaje que se puede emitir por el socket.
public protocol OutgoingMessageRepresentable {
    var event: String { get }
    var payload: Data? { get }
    var recipientId: String? { get }
    var metadata: [String: String]? { get }
}


public protocol IncomingMessageRepresentable {
    var event: String { get }
    var content: String { get }
    var senderId: String { get }
    var timestamp: Date { get }
    var metadata: [String: String]? { get }
}

// MARK: - Protocolo base para el cliente tipo Engine.IO
public protocol EngineIOClient {
    func connect(url: URL, path: String, auth: [String: String])
    func send(message: String)
    func disconnect()
    func listen(onMessage: @escaping (String) -> Void)
}


// MARK: - Reconnect Strategy

public protocol ReconnectStrategy {
    /// Devuelve el tiempo de espera antes del siguiente intento, según el número de reintentos previos.
    func delay(for attempt: Int) -> TimeInterval
    var maxAttempts: Int { get }
}

// MARK: - Socket Middleware

public protocol SocketMiddleware {
    /// Permite modificar o bloquear eventos antes de ser propagados a los listeners.
    func process(event: String, data: Any) -> (event: String, data: Any)?
}

// MARK: - Socket Logger

public protocol SocketLogger {
    /// Registra eventos de debug o producción.
    func log(event: String, data: Any)
}

// MARK: - Socket Storage

public protocol SocketStorage {
    /// Guarda un mensaje pendiente para reintento u offline.
    func storeOutgoingMessage(_ message: OutgoingMessageRepresentable)
    
    /// Recupera mensajes pendientes.
    func retrievePendingMessages() -> [OutgoingMessageRepresentable]
    
    /// Limpia todos los mensajes almacenados.
    func clearStoredMessages()
}

