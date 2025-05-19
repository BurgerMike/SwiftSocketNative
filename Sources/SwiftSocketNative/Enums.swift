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

    // Errores de flujo de usuario
    case messageTooLong
    case emptyMessage
    case recipientNotFound(String)

    // Errores de lógica del servidor o autenticación
    case unauthorized(String)
    case forbidden(String)
    case serverError(code: Int, message: String)

    // Errores de red o formato
    case noInternet
    case badResponseFormat
    case timeoutDuringEmit

    // Fallos internos
    case internalFailure(String)
    case decodingMismatch(expected: String, actual: String)
}

// MARK: - SocketErrorHandler

public protocol SocketErrorHandler {
    /// Maneja errores generados por el sistema de sockets
    func handle(error: SocketError, context: String?)
}

extension SocketError {
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
        case .messageTooLong: return "El mensaje supera el límite permitido."
        case .emptyMessage: return "El mensaje está vacío."
        case .recipientNotFound(let userId): return "No se encontró al destinatario con ID: \(userId)"
        case .unauthorized(let reason): return "No autorizado: \(reason)"
        case .forbidden(let reason): return "Acceso denegado: \(reason)"
        case .serverError(let code, let message): return "Error del servidor (\(code)): \(message)"
        case .noInternet: return "No hay conexión a Internet."
        case .badResponseFormat: return "El formato de la respuesta del servidor no es válido."
        case .timeoutDuringEmit: return "Se agotó el tiempo de espera al emitir un mensaje."
        case .internalFailure(let reason): return "Fallo interno: \(reason)"
        case .decodingMismatch(let expected, let actual): return "Error de decodificación. Esperado: \(expected), recibido: \(actual)"
        }
    }
}

public extension SocketError {
    func log(tag: String = "🧩 Socket") {
        print("❌ [\(tag)] \(self.description)")
    }
}
