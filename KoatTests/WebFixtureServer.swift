import Foundation
import Network
import CoreGraphics

/// A loopback HTTP server with real Turbo and a manually released slow response.
/// No Rails process, credentials or external network is required by these tests.
final class WebFixtureServer {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "KoatTests.HTTP")
    private let turbo: Data
    private let pdf: Data
    private var heldResponses: [NWConnection] = []
    private var connections: [NWConnection] = []
    private var holdExercises = true
    private var recordedRequests: [String] = []
    private var pdfCookie = false
    private var checkoutCookie = false

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
        turbo = try Data(contentsOf: Bundle(for: WebNavigationTests.self).url(forResource: "turbo", withExtension: "js")!)
        let output = NSMutableData()
        let consumer = CGDataConsumer(data: output)!
        var bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let context = CGContext(consumer: consumer, mediaBox: &bounds, nil)!
        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()
        pdf = output as Data
    }

    var rootURL: URL { URL(string: "http://127.0.0.1:\(listener.port!.rawValue)/")! }
    var hasHeldResponse: Bool { queue.sync { !heldResponses.isEmpty } }
    var requests: [String] { queue.sync { recordedRequests } }
    var checkoutReceivedSessionCookie: Bool { queue.sync { checkoutCookie } }
    var pdfReceivedSessionCookie: Bool { queue.sync { pdfCookie } }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready: continuation.resume()
                case .failed(let error): continuation.resume(throwing: error)
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                self.connections.append(connection)
                connection.start(queue: self.queue)
                self.receive(connection)
            }
            listener.start(queue: queue)
        }
    }

    func stop() {
        queue.sync {
            listener.cancel()
            connections.forEach { $0.cancel() }
            connections.removeAll()
        }
    }

    func releaseExercises() {
        queue.sync {
            holdExercises = false
            heldResponses.forEach { respond($0, body: page("exercises")) }
            heldResponses.removeAll()
        }
    }

    private func receive(_ connection: NWConnection, prefix: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self, let data else { return }
            let request = prefix + data
            guard let text = String(data: request, encoding: .utf8), text.contains("\r\n\r\n") else {
                if !complete && error == nil { self.receive(connection, prefix: request) }
                return
            }
            let path = String(text.split(separator: " ")[1])
            self.recordedRequests.append(path)
            switch path.split(separator: "?").first.map(String.init) {
            case "/turbo.js": self.respond(connection, body: self.turbo, type: "text/javascript")
            case "/exercises":
                if self.holdExercises { self.heldResponses.append(connection) }
                else { self.respond(connection, body: self.page("exercises")) }
            case "/session":
                self.respond(connection, body: Data(), status: "302 Found", headers: "Location: /signed-in\r\nSet-Cookie: session_id=test-session; Path=/; HttpOnly\r\n")
            case "/escape":
                self.respond(connection, body: Data(), status: "302 Found", headers: "Location: http://localhost:\(self.listener.port!.rawValue)/outside\r\n")
            case "/subscriptions/checkouts":
                self.respond(connection, body: Data(), status: "303 See Other", headers: "Location: https://checkout.stripe.com/c/pay/koat-test\r\n")
            case "/subscriptions/checkouts/123": self.respond(connection, body: self.page("checkout"))
            case "/subscriptions/checkouts/123/return":
                self.checkoutCookie = text.contains("session_id=test-session")
                self.respond(connection, body: self.page("checkout-return"))
            case "/onboarding": self.respond(connection, body: self.page("onboarding"))
            case "/subscriptions": self.respond(connection, body: self.page("subscriptions"))
            case "/offline": connection.cancel()
            case "/signed-in": self.respond(connection, body: self.page("signed-in"))
            case "/settings": self.respond(connection, body: self.page("settings"))
            case "/plain": self.respond(connection, body: self.page("plain", turboEnabled: false))
            case "/popup": self.respond(connection, body: self.page("popup"))
            case "/pdf":
                self.pdfCookie = text.contains("session_id=test-session")
                self.respond(connection, body: self.pdf, type: "application/pdf")
            default: self.respond(connection, body: self.page("home"))
            }
        }
    }

    private func page(_ name: String, turboEnabled: Bool = true) -> Data {
        Data("""
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>\(name)</title>\(turboEnabled ? "<script type='module' src='/turbo.js'></script>" : "")
        </head><body data-page="\(name)"><h1>\(name)</h1>
        <nav id="navbar"><a id="exercises" href="/exercises">Exercícios</a>
        <a id="settings" href="/settings">Mais</a><a href="/" id="home">Home</a></nav>
        <form action="/subscriptions/checkouts" method="post" data-turbo="false" id="checkout-form"><button>Checkout</button></form>
        <a href="/popup" target="_blank" id="popup">Open</a>
        </body></html>
        """.utf8)
    }

    private func respond(_ connection: NWConnection, body: Data, type: String = "text/html", status: String = "200 OK", headers: String = "") {
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(type); charset=utf-8\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\(headers)\r\n"
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }
}
