//
//  Struct.swift
//  SwiftSocketNative
//
//  Created by Miguel Carlos Elizondo Martinez on 15/05/25.
//
import Foundation

public struct SocketEvent: Codable, Equatable, Sendable, SocketEventRepresentable {
    public let event: String
    public let payload: Data?
    public let namespace: String?

    public init(event: String, payload: Data?, namespace: String? = nil) {
        self.event = event
        self.payload = payload
        self.namespace = namespace
    }
}


/// Representa un mensaje saliente estándar para ser emitido por el socket.
public struct OutgoingMessage: Codable, Sendable, Equatable, OutgoingMessageRepresentable {
    public let event: String
    public let payload: Data?
    public let recipientId: String?
    public let metadata: [String: String]?
    public let ackId: String?

    public init<T: Encodable>(
        event: String,
        payloadObject: T?,
        recipientId: String? = nil,
        metadata: [String: String]? = nil,
        ackId: String? = nil
    ) {
        self.event = event
        self.recipientId = recipientId
        self.metadata = metadata
        self.ackId = ackId
        self.payload = payloadObject.flatMap { try? JSONEncoder().encode($0) }
    }
}

/// Representa un mensaje recibido desde el socket.
public struct IncomingMessage: Codable, Sendable, Equatable, IncomingMessageRepresentable {
    public let event: String
    public let content: String
    public let senderId: String
    public let timestamp: Date
    public let metadata: [String: String]?
    public let ackId: String?
    public let socketId: String?
    public let payload: Data?
    
    public init(
        event: String,
        content: String,
        senderId: String,
        timestamp: Date = .now,
        metadata: [String: String]? = nil,
        ackId: String? = nil,
        socketId: String? = nil,
        payload: Data? = nil
    ) {
        self.event = event
        self.content = content
        self.senderId = senderId
        self.timestamp = timestamp
        self.metadata = metadata
        self.ackId = ackId
        self.socketId = socketId
        self.payload = payload
    }
}

public extension IncomingMessage {
    func decodePayload<T: Decodable>(as type: T.Type) -> T? {
        guard let payload else { return nil }
        return try? JSONDecoder().decode(T.self, from: payload)
    }
}
