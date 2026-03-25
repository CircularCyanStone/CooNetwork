//
//  ViewController.swift
//  PodExample
//
//  Created by 李奇奇 on 2026/1/7.
//

import UIKit
import CooNetwork
import Alamofire

class ViewController: UIViewController {

    // 测试执行器
    private let testRunner = TestRunner()
    private var currentTestTask: Task<Void, Never>?

    // UI 组件
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "CooNetwork 集成测试"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private lazy var quickTestButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("🚀 快速验证", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(runQuickTests), for: .touchUpInside)
        return button
    }()

    private lazy var fullTestButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("📊 全面测试", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(runFullTests), for: .touchUpInside)
        return button
    }()

    private lazy var clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("🗑️ 清理", for: .normal)
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(clearResults), for: .touchUpInside)
        return button
    }()

    private lazy var resultTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = .systemBackground
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        return textView
    }()

    private lazy var individualTestButtonsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        testJSONSerializationCast()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // 添加子视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(titleLabel)
        contentView.addSubview(quickTestButton)
        contentView.addSubview(fullTestButton)
        contentView.addSubview(clearButton)
        contentView.addSubview(resultTextView)
        contentView.addSubview(individualTestButtonsStack)

        // 创建单个测试按钮
        let testNames = ["T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8"]
        let testSuites = getAllTestSuites()

        for (index, name) in testNames.enumerated() {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle(name, for: .normal)
            button.backgroundColor = .systemOrange
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 6
            button.tag = index
            button.addTarget(self, action: #selector(runIndividualTest(_:)), for: .touchUpInside)
            individualTestButtonsStack.addArrangedSubview(button)
        }

        // 布局约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            quickTestButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            quickTestButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            quickTestButton.widthAnchor.constraint(equalToConstant: 100),
            quickTestButton.heightAnchor.constraint(equalToConstant: 40),

            fullTestButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            fullTestButton.leadingAnchor.constraint(equalTo: quickTestButton.trailingAnchor, constant: 10),
            fullTestButton.widthAnchor.constraint(equalToConstant: 100),
            fullTestButton.heightAnchor.constraint(equalToConstant: 40),

            clearButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            clearButton.leadingAnchor.constraint(equalTo: fullTestButton.trailingAnchor, constant: 10),
            clearButton.widthAnchor.constraint(equalToConstant: 80),
            clearButton.heightAnchor.constraint(equalToConstant: 40),

            individualTestButtonsStack.topAnchor.constraint(equalTo: quickTestButton.bottomAnchor, constant: 20),
            individualTestButtonsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            individualTestButtonsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            individualTestButtonsStack.heightAnchor.constraint(equalToConstant: 40),

            resultTextView.topAnchor.constraint(equalTo: individualTestButtonsStack.bottomAnchor, constant: 20),
            resultTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultTextView.heightAnchor.constraint(equalToConstant: 400),
            resultTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    @objc private func runQuickTests() {
        cancelCurrentTest()

        currentTestTask = Task {
            await executeTests(getQuickTestSuites())
        }
    }

    @objc private func runFullTests() {
        cancelCurrentTest()

        currentTestTask = Task {
            await executeTests(getAllTestSuites())
        }
    }

    @objc private func runIndividualTest(_ sender: UIButton) {
        cancelCurrentTest()

        let index = sender.tag
        let testSuites = getAllTestSuites()

        guard index < testSuites.count else { return }

        currentTestTask = Task {
            let result = await testRunner.runSuite(testSuites[index])
            await MainActor.run {
                appendResult(result.formattedOutput)
            }
        }
    }

    @objc private func clearResults() {
        cancelCurrentTest()
        resultTextView.text = ""
        // NtkConfiguration.shared.clearCache()
    }

    private func cancelCurrentTest() {
        currentTestTask?.cancel()
        currentTestTask = nil
    }

    private func executeTests(_ suites: [TestSuite]) async {
        await MainActor.run {
            resultTextView.text = "开始测试...\n\n"
        }

        let results = await testRunner.runAll(suites: suites)

        await MainActor.run {
            var output = "测试完成！\n\n"
            for result in results {
                output += result.formattedOutput + "\n\n"
            }
            resultTextView.text = output

            // 生成完整报告（暂时禁用 actor-isolated 方法调用）
            // let report = testRunner.generateReport()
            // print("\n完整测试报告：\n\(report)")
        }
    }

    private func appendResult(_ text: String) {
        let currentText = resultTextView.text ?? ""
        resultTextView.text = currentText + "\n\n" + text
    }
}

// MARK: - Old IPv6 Test (保留用于手动测试)

struct IPv6Response: Decodable, Sendable {
    let ip: String
    let type: String
    let subtype: String?
    let via: String?
    let padding: String?
}

struct IPv6Request: iAFRequest {
    let urlStr: String

    var baseURL: URL? {
        return URL(string: urlStr)
    }

    var path: String {
        return ""
    }

    var method: NtkHTTPMethod {
        return .get
    }

    var parameters: [String : any Sendable]? {
        return ["callback": "myCallback", "testdomain": "test-ipv6.com", "testname": "test_a"]
    }

    var checkLogin: Bool {
        return false
    }
}

struct IPv6ParsingInterceptor: iNtkResponseParser {
    func intercept(context: NtkInterceptorContext, next: any iNtkRequestHandler) async throws -> any iNtkResponse {
        let response = try await next.handle(context: context)

        let rawData: Data
        if let clientResponse = response as? NtkClientResponse {
            if let d = clientResponse.data as? Data {
                rawData = d
            } else if let d = clientResponse.response as? Data {
                rawData = d
            } else {
                throw NtkError.serviceDataEmpty
            }
        } else {
             throw NtkError.typeMismatch
        }

        guard let string = String(data: rawData, encoding: .utf8) else {
            throw NtkError.decodeInvalid(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid UTF8 Data")), rawData)
        }

        guard let firstBrace = string.firstIndex(of: "{"),
              let lastBrace = string.lastIndex(of: "}") else {
            throw NtkError.decodeInvalid(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid JSONP format")), rawData)
        }

        let jsonString = String(string[firstBrace...lastBrace])
        guard let jsonBytes = jsonString.data(using: .utf8) else {
             throw NtkError.decodeInvalid(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid JSON string")), rawData)
        }

        let decoder = JSONDecoder()
        let model = try decoder.decode(IPv6Response.self, from: jsonBytes)

        return NtkResponse(
            code: NtkReturnCode(0),
            data: model,
            msg: "Success",
            response: response,
            request: context.mutableRequest.originalRequest,
            isCache: response.isCache
        )
    }
}

struct IPv6Validation: iNtkResponseValidation {
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool {
        return true
    }
}

func testJSONSerializationCast() {
    let jsonString = "{\"code\":0,\"msg\":\"error\",\"data\":{\"id\":1,\"name\":\"test\"}}"
    let data = jsonString.data(using: .utf8)!

    // 测试1: as? [AnyHashable: any Sendable]
    if let result = try? JSONSerialization.jsonObject(with: data) as? [AnyHashable: any Sendable] {
        print("✅ [AnyHashable: any Sendable] 转换成功: \(result)")
    } else {
        print("❌ [AnyHashable: any Sendable] 转换失败")
    }

    // 测试2: as? [String: any Sendable]
    if let result = try? JSONSerialization.jsonObject(with: data) as? [String: any Sendable] {
        print("✅ [String: any Sendable] 转换成功: \(result)")
    } else {
        print("❌ [String: any Sendable] 转换失败")
    }

    // 测试3: as? NSDictionary（基准）
    if let result = try? JSONSerialization.jsonObject(with: data) as? NSDictionary {
        print("✅ NSDictionary 转换成功: \(result)")
    } else {
        print("❌ NSDictionary 转换失败")
    }

    // 测试4: as? [String: Any]（基准）
    if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        print("✅ [String: Any] 转换成功: \(result)")
    } else {
        print("❌ [String: Any] 转换失败")
    }
}

func testIPv6() {
    Task {
        print("\n🚀 Starting IPv4 Test...")
        let url1 = "https://ipv4.tokyo.test-ipv6.com/ip/"
        let req1 = IPv6Request(urlStr: url1)

        do {
            let result1 = try await NtkAF<IPv6Response>.withAF(
                req1,
                validation: IPv6Validation(),
                responseParser: IPv6ParsingInterceptor()
            ).request()
            print("✅ IPv4 Result: IP=\(result1.data.ip), Type=\(result1.data.type)")
        } catch {
            print("❌ IPv4 Failed: \(error)")
        }

        print("\n🚀 Starting IPv6 Test...")
        let url2 = "https://ipv6.tokyo.test-ipv6.com/ip/"
        let req2 = IPv6Request(urlStr: url2)

        do {
            let result2 = try await NtkAF<IPv6Response>.withAF(
                req2,
                validation: IPv6Validation(),
                responseParser: IPv6ParsingInterceptor()
            ).request()
            print("✅ IPv6 Result: IP=\(result2.data.ip), Type=\(result2.data.type)")
        } catch {
            print("❌ IPv6 Failed: \(error)")
        }
    }
}
