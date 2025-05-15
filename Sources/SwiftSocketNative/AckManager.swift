import Foundation


////// Implementación por defecto de un manejador de ACKs.
public final class AckManager: AckHandler, @unchecked Sendable {
    private var acks: [String: (timer: Timer, callback: (Result<Any?, SocketError>) -> Void)] = [:]
    private let queue = DispatchQueue(label: "AckManagerQueue", attributes: .concurrent)

    public init() {}

    public func addAck(id: String, timeout: TimeInterval = 5.0, callback: @escaping (Result<Any?, SocketError>) -> Void) {
        queue.async(flags: .barrier) {
            let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                self?.failAck(id: id, error: .ackTimeout)
            }
            self.acks[id] = (timer, callback)
        }
    }

    public func resolveAck(id: String, with data: Any?) {
        queue.async(flags: .barrier) {
            guard let (timer, callback) = self.acks.removeValue(forKey: id) else { return }
            timer.invalidate()
            callback(.success(data))
        }
    }

    public func failAck(id: String, error: SocketError) {
        queue.async(flags: .barrier) {
            guard let (timer, callback) = self.acks.removeValue(forKey: id) else { return }
            timer.invalidate()
            callback(.failure(error))
        }
    }

    public func cancelAll() {
        queue.async(flags: .barrier) {
            for (_, value) in self.acks {
                value.timer.invalidate()
                value.callback(.failure(.ackTimeout))
            }
            self.acks.removeAll()
        }
    }
}
