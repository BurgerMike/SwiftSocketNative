//
//  Enum.swift
//  SwiftSocket.ioNative
//
//  Created by Miguel Carlos Elizondo Martinez on 15/05/25.
//
import Foundation

public enum SocketError: Error, CustomStringConvertible, Equatable, Sendable {
    case notConnected
    case webSocketUnavailable
    case encodingFailed
    case decodingFailed
    case ackTimeout
    case connectionTimeout
    case reconnectFailed
    case unknownEvent(String)
    case custom(String)

    public var description: String {
        switch self {
        case .notConnected: return "No hay conexión activa."
        case .webSocketUnavailable: return "El WebSocket no está disponible."
        case .encodingFailed: return "Fallo al codificar los datos."
        case .decodingFailed: return "Fallo al decodificar los datos recibidos."
        case .ackTimeout: return "Tiempo de espera para el ACK superado."
        case .connectionTimeout: return "La conexión ha excedido el tiempo de espera."
        case .reconnectFailed: return "No se logró reconectar después de múltiples intentos."
        case .unknownEvent(let name): return "Evento desconocido: \(name)"
        case .custom(let msg): return msg
        }
    }
}
