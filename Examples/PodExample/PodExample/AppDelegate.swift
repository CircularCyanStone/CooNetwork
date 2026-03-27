//
//  AppDelegate.swift
//  PodExample
//
//  Created by 李奇奇 on 2026/1/7.
//

import UIKit

// MARK: - JSON 解析错误测试用模型

struct UserModel: Decodable {
    let id: Int
    let name: String
    let email: String
    let age: Int
}

struct NestedModel: Decodable {
    let user: UserModel
}

// MARK: - JSON 解析错误测试

func runJSONDecodeErrorTests() {

    let decoder = JSONDecoder()

    // -------- 测试 1: typeMismatch --------
    // id 字段应为 Int，但 JSON 里给了 String
    let typeMismatchJSON = """
    {"id": "not_an_int", "name": "张三", "email": "z@example.com", "age": 18}
    """
    do {
        _ = try decoder.decode(UserModel.self, from: Data(typeMismatchJSON.utf8))
    } catch let error as DecodingError {
        print("\n========== 测试1: typeMismatch ==========")
        printDecodingError(error)
    } catch {
        print("其他错误: \(error)")
    }

    // -------- 测试 2: valueNotFound --------
    // age 字段值为 null
    let valueNotFoundJSON = """
    {"id": 1, "name": "张三", "email": "z@example.com", "age": null}
    """
    do {
        _ = try decoder.decode(UserModel.self, from: Data(valueNotFoundJSON.utf8))
    } catch let error as DecodingError {
        print("\n========== 测试2: valueNotFound ==========")
        printDecodingError(error)
    } catch {
        print("其他错误: \(error)")
    }

    // -------- 测试 3: keyNotFound --------
    // 缺少必须的 email 字段
    let keyNotFoundJSON = """
    {"id": 1, "name": "张三", "age": 18}
    """
    do {
        _ = try decoder.decode(UserModel.self, from: Data(keyNotFoundJSON.utf8))
    } catch let error as DecodingError {
        print("\n========== 测试3: keyNotFound ==========")
        printDecodingError(error)
    } catch {
        print("其他错误: \(error)")
    }

    // -------- 测试 4: dataCorrupted (非法 JSON) --------
    let corruptedJSON = "this is not json at all"
    do {
        _ = try decoder.decode(UserModel.self, from: Data(corruptedJSON.utf8))
    } catch let error as DecodingError {
        print("\n========== 测试4: dataCorrupted ==========")
        printDecodingError(error)
    } catch {
        print("其他错误: \(error)")
    }

    // -------- 测试 5: 嵌套结构中的 keyNotFound --------
    // 嵌套对象 user 内部缺少字段，codingPath 会显示完整路径
    let nestedKeyNotFoundJSON = """
    {"user": {"id": 1, "name": "张三", "age": 18}}
    """
    do {
        _ = try decoder.decode(NestedModel.self, from: Data(nestedKeyNotFoundJSON.utf8))
    } catch let error as DecodingError {
        print("\n========== 测试5: 嵌套 keyNotFound ==========")
        printDecodingError(error)
    } catch {
        print("其他错误: \(error)")
    }
}

// MARK: - DecodingError 详细打印

func printDecodingError(_ error: DecodingError) {
    switch error {
    case .typeMismatch(let type, let context):
        print("[typeMismatch]")
        print("  期望类型: \(type)")
        print("  codingPath: \(context.codingPath.map { $0.stringValue })")
        print("  debugDescription: \(context.debugDescription)")
        if let underlying = context.underlyingError {
            print("  underlyingError: \(underlying)")
        }

    case .valueNotFound(let type, let context):
        print("[valueNotFound]")
        print("  期望类型: \(type)")
        print("  codingPath: \(context.codingPath.map { $0.stringValue })")
        print("  debugDescription: \(context.debugDescription)")
        if let underlying = context.underlyingError {
            print("  underlyingError: \(underlying)")
        }

    case .keyNotFound(let key, let context):
        print("[keyNotFound]")
        print("  缺失的 key: \(key.stringValue)")
        print("  codingPath: \(context.codingPath.map { $0.stringValue })")
        print("  debugDescription: \(context.debugDescription)")
        if let underlying = context.underlyingError {
            print("  underlyingError: \(underlying)")
        }

    case .dataCorrupted(let context):
        print("[dataCorrupted]")
        print("  codingPath: \(context.codingPath.map { $0.stringValue })")
        print("  debugDescription: \(context.debugDescription)")
        if let underlying = context.underlyingError {
            print("  underlyingError: \(underlying)")
        }

    @unknown default:
        print("[unknown DecodingError]: \(error)")
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 启动时运行 JSON 解析错误测试
//        runJSONDecodeErrorTests()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
