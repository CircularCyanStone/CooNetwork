//
//  TestModels.swift
//  PodExample
//
//  Created by Claude Code on 2026/3/15.
//

import Foundation
import CooNetwork

// MARK: - JSONPlaceholder Models

struct Post: Decodable, Sendable {
    let userId: Int
    let id: Int
    let title: String
    let body: String
}

struct Comment: Decodable, Sendable {
    let postId: Int
    let id: Int
    let name: String
    let email: String
    let body: String
}

struct HttpBinResponse: Decodable, Sendable {
    let args: [String: String]
    let headers: [String: String]
    let origin: String
    let url: String
}

// MARK: - Test Result Models

enum TestStatus {
    case passed
    case failed
    case skipped

    var emoji: String {
        switch self {
        case .passed: return "✅"
        case .failed: return "❌"
        case .skipped: return "⏭"
        }
    }

    var displayName: String {
        switch self {
        case .passed: return "PASSED"
        case .failed: return "FAILED"
        case .skipped: return "SKIPPED"
        }
    }
}

struct TestResult: Sendable {
    let name: String
    let status: TestStatus
    let duration: TimeInterval
    let details: String
    let evidence: String?

    var formattedOutput: String {
        var output = "\(status.emoji) \(name) (\(String(format: "%.2f", duration))s)\n"
        output += "   Status: \(status.displayName)\n"
        output += "   Details: \(details)"
        if let evidence = evidence {
            output += "\n   Evidence: \(evidence)"
        }
        return output
    }
}

struct TestSuite {
    let name: String
    let description: String
    let action: () async throws -> TestResult
}

// MARK: - Test Requests

struct JSONPlaceholderRequest: iAFRequest {
    let path: String
    let method: NtkHTTPMethod
    let parameters: [String: any Sendable]?

    var baseURL: URL? {
        URL(string: "https://jsonplaceholder.typicode.com")
    }

    var checkLogin: Bool {
        false
    }
}

struct HttpBinRequest: iAFRequest {
    let path: String
    let method: NtkHTTPMethod
    let parameters: [String: any Sendable]?

    var baseURL: URL? {
        URL(string: "https://httpbin.org")
    }

    var checkLogin: Bool {
        false
    }
}

// MARK: - Test Validation

struct StandardValidation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        // 对于 JSONPlaceholder 和 HTTPBin，只要能解析出 NtkResponse 就成功
        return true
    }
}
