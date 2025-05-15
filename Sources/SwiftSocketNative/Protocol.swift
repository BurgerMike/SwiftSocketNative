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
    /// Inicia la conexión con el servidor.
    func connect()

    /// Cierra la conexión.
    func disconnect()

    /// Envía un evento con datos opcionales y maneja respuesta ACK si aplica.
    func emit<T: Encodable>(event: String, data: T?, ack: ((Result<Void, SocketError>) -> Void)?)

    /// Escucha un evento personalizado del servidor.
    func on(event: String, callback: @escaping (Any) -> Void)

    /// Escucha eventos internos del sistema (como connect, disconnect, error).
    func onSystem(event: String, callback: @escaping (Any) -> Void)

    /// Elimina el listener para un evento.
    func off(event: String)
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
