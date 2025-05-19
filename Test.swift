//
//  TEst.swift
//  SwiftSocketNative
//
//  Created by SpongeMikeiOSMaster on 19/05/25.
//

import SwiftSocketNative
import Testing

@testable import SwiftSocketNative

#Test("OutgoingMessage encoding") {
    struct TestPayload: Codable, Equatable {
        let text: String
    }

    let payload = TestPayload(text: "Hola mundo")
    let message = OutgoingMessage(event: "prueba", payloadObject: payload, ackId: "123")

    #expect(message.event == "prueba")
    #expect(message.ackId == "123")

    let decoded = try JSONDecoder().decode(TestPayload.self, from: message.payload!)
    #expect(decoded == payload)
}

#Test("IncomingMessage decoding") {
    struct TestPayload: Codable, Equatable {
        let text: String
    }

    let payload = TestPayload(text: "Respuesta")
    let payloadData = try JSONEncoder().encode(payload)

    let message = IncomingMessage(
        event: "respuesta",
        content: "respuesta recibida",
        senderId: "user1",
        payload: payloadData
    )

    let decoded: TestPayload? = message.decodePayload(as: TestPayload.self)
    #expect(decoded == payload)
}
