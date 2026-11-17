import Foundation

/// One possible cause returned by a symptom check.
nonisolated struct SymptomCause: Codable, Hashable {
    var name: String
    var matchPercent: Int        // 0–100, how closely it fits what was described
    var label: String            // "Most likely", "Possible", "Less likely", "Needs a test", "See a doctor"
    var explanation: String
}

nonisolated struct SymptomReport: Codable, Hashable {
    var causes: [SymptomCause]
    var urgent: Bool             // true → red-flag symptoms, tell the user to get care now
    var urgentAdvice: String
}

/// Runs a symptom check with the user's own AI key (Profile → AI provider key).
/// Only the symptom text the user typed is sent — nothing from the cabinet or profile.
/// Results are informational and the UI always frames them as "not a diagnosis".
nonisolated enum SymptomAI {

    enum Failure: LocalizedError {
        case noKey, declined, badResponse(String), http(Int, String)
        var errorDescription: String? {
            switch self {
            case .noKey: "Add your AI provider key in Profile → AI provider key to run a check."
            case .declined: "The AI declined this request. If you feel unwell, contact a doctor or pharmacist."
            case .badResponse(let why): "Couldn't read the AI's answer (\(why)). Try again."
            case .http(let code, let body): "The AI provider returned an error (\(code)). \(body)"
            }
        }
    }

    static let instructions = """
    You help a patient understand what everyday symptoms might point to. You are not a doctor and never diagnose.
    Given their description, list 2 to 4 plausible common causes, most likely first. For each give:
    - name: plain-English condition name
    - matchPercent: an integer 0-100 for how well it fits what they described (a rough fit, not a probability)
    - label: exactly one of "Most likely", "Possible", "Less likely", "Needs a test", "See a doctor"
    - explanation: 1-3 short sentences on why it fits and what usually helps or when to see someone
    Set urgent to true only for red flags (chest pain, trouble breathing, signs of stroke, severe bleeding,
    confusion, a very high fever, severe allergic reaction, thoughts of self-harm) and put one clear sentence in
    urgentAdvice telling them to get emergency care now. Otherwise urgent is false and urgentAdvice is "".
    Never recommend prescription-only medicines or doses. Answer only with the JSON object.
    """

    private static let schema: [String: Any] = [
        "type": "object",
        "properties": [
            "causes": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "matchPercent": ["type": "integer"],
                        "label": ["type": "string",
                                  "enum": ["Most likely", "Possible", "Less likely", "Needs a test", "See a doctor"]],
                        "explanation": ["type": "string"]
                    ],
                    "required": ["name", "matchPercent", "label", "explanation"],
                    "additionalProperties": false
                ]
            ],
            "urgent": ["type": "boolean"],
            "urgentAdvice": ["type": "string"]
        ],
        "required": ["causes", "urgent", "urgentAdvice"],
        "additionalProperties": false
    ]

    static func check(symptoms: String, provider: String) async throws -> SymptomReport {
        guard let key = Keychain.get(account: Keychain.aiKeyAccount), !key.isEmpty else { throw Failure.noKey }
        let json: String
        switch provider {
        case "Claude": json = try await claude(symptoms, key: key)
        case "OpenAI": json = try await openAI(symptoms, key: key)
        default: json = try await gemini(symptoms, key: key)
        }
        guard let data = json.data(using: .utf8),
              var report = try? JSONDecoder().decode(SymptomReport.self, from: data) else {
            throw Failure.badResponse("unexpected format")
        }
        report.causes = report.causes.map { var c = $0; c.matchPercent = min(max(c.matchPercent, 0), 100); return c }
        return report
    }

    // MARK: Providers

    /// Claude Messages API (raw HTTP — there is no official Swift SDK). Structured outputs
    /// guarantee the JSON matches `schema`; `fallbacks: "default"` re-runs a classifier
    /// decline on Anthropic's recommended fallback model instead of failing.
    private static func claude(_ symptoms: String, key: String) async throws -> String {
        let body: [String: Any] = [
            "model": "claude-opus-5-5",
            "max_tokens": 16000,
            "system": instructions,
            "output_config": ["effort": "medium", "format": ["type": "json_schema", "schema": schema]],
            "fallbacks": "default",
            "messages": [["role": "user", "content": symptoms]]
        ]
        let response = try await post("https://api.anthropic.com/v1/messages", body: body, headers: [
            "x-api-key": key,
            "anthropic-version": "2026-10-21",
            "anthropic-beta": "server-side-fallback-2026-07-01"
        ])
        if response["stop_reason"] as? String == "refusal" { throw Failure.declined }
        let blocks = response["content"] as? [[String: Any]] ?? []
        guard let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String else {
            throw Failure.badResponse("no text in reply")
        }
        return text
    }

    private static func gemini(_ symptoms: String, key: String) async throws -> String {
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": instructions]]],
            "contents": [["role": "user", "parts": [["text": symptoms]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        let response = try await post(
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
            body: body, headers: ["x-goog-api-key": key])
        let candidates = response["candidates"] as? [[String: Any]] ?? []
        let parts = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
        guard let text = parts.first?["text"] as? String else { throw Failure.badResponse("no text in reply") }
        return text
    }

    private static func openAI(_ symptoms: String, key: String) async throws -> String {
        let body: [String: Any] = [
            "model": "gpt-4.1-mini",
            "response_format": ["type": "json_object"],
            "messages": [["role": "system", "content": instructions], ["role": "user", "content": symptoms]]
        ]
        let response = try await post("https://api.openai.com/v1/chat/completions", body: body,
                                      headers: ["Authorization": "Bearer \(key)"])
        let choices = response["choices"] as? [[String: Any]] ?? []
        guard let text = (choices.first?["message"] as? [String: Any])?["content"] as? String else {
            throw Failure.badResponse("no text in reply")
        }
        return text
    }

    private static func post(_ url: String, body: [String: Any], headers: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            let message = ((json["error"] as? [String: Any])?["message"] as? String) ?? ""
            throw Failure.http(status, message)
        }
        return json
    }
}
