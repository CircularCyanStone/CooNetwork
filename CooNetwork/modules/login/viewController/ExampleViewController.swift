//
//  ExampleViewController.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/14.
//

import UIKit
import SwiftUI

class ExampleViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置SwiftUI桥接
        setupSwiftUIBridge()
    }
    
    private func setupSwiftUIBridge() {
        // 创建SwiftUI视图
        let swiftUIView = ExampleSwiftUIView()
        
        // 使用UIHostingController桥接SwiftUI
        let hostingController = UIHostingController(rootView: swiftUIView)
        
        // 添加为子视图控制器
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // 设置约束
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}

// MARK: - SwiftUI View
struct ExampleSwiftUIView: View {
    @State private var counter = 0
    @State private var text = "Hello SwiftUI!"
    
    @State var stream: AsyncThrowingStream<NtkResponse<CodeData>, any Error>?
    
    // 测试管理器
    @StateObject private var deduplicationTestManager = DeduplicationTestManager()
    @StateObject private var retryTestManager = RetryTestManager()
    
    private func loadTime() {
        Task {
            do {
                let response: Int = try await DefaultCoo.with(Login.getTime).sendRequest().data
                print("\(response)")
            }catch let error as NtkError {
                print("\(error)")
            }catch {
                print("\(error)")
            }
        }
    }
    
    var body: some View {
        ZStack {    
            List {
                Button {
                    let actorExample = CooActorExample()
                    Task {
                        await actorExample.modifyName("ccc")
                        await actorExample.changeSchool()
                    }
                } label: {
                    HStack {
                        Text("actor测试")
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .contentShape(Rectangle()) // 使整个HStack区域可点击
                }
                .buttonStyle(.plain)
                .background(Color.brown)
                .listRowBackground(Color.orange)
                .listRowInsets(EdgeInsets()) // 去除List的默认行内边距
                
                Button(action: {
                    let actorExample = CooActorExample()
                    Task {
                        await actorExample.modifyName("ccc")
                        await actorExample.changeSchool()
                    }
                }) {
                    HStack {
                        Text("actor测试")
                            .font(.system(size: 14))
                        Spacer() // 推开内容，确保背景填满
                    }
                    .padding(.vertical, 10) // 为内容添加垂直内边距，根据需要调整
                    .frame(maxWidth: .infinity, alignment: .leading) // 确保HStack填满宽度，内容左对齐
                    .contentShape(Rectangle()) // 使整个HStack区域可点击
                }
                .buttonStyle(.plain) // 关键：去除 Button 自身的默认样式和内边距
                .listRowBackground(Color.orange) // 设置行背景色
                .listRowSeparator(.hidden) // 隐藏行之间的分隔线
                .listRowInsets(EdgeInsets()) // 去除List的默认行内边距
                

                Button("请求短信") {
                    Task {
                        do {
                            let req = Login.sendSMS("300343", tmpLogin: false)
                            
                            let cacheData: CodeData? = try await DefaultCoo.with(req).loadCache()?.data
                            
                            
                            let codeResult: CodeData = try await DefaultCoo.with(req, validation: req).hud(true).sendRequest().data
                            print("短信发送成功")
                        }catch {
                            print("短信发送失败 \(error)")
                        }
                    }
                }
                .frame(minHeight: 150)
                .listRowInsets(EdgeInsets()) // 去除List的默认行内边距
                .listRowBackground(Color.orange)
                
                // MARK: - 请求去重测试区域
                Section("请求去重测试") {
                    Button("并发去重测试") {
                        deduplicationTestManager.testConcurrentDeduplication()
                    }
                    .listRowBackground(Color.blue.opacity(0.3))
                    
                    Button("顺序去重测试") {
                        deduplicationTestManager.testSequentialDeduplication()
                    }
                    .listRowBackground(Color.blue.opacity(0.3))
                    
                    Button("禁用去重测试") {
                        deduplicationTestManager.testDisabledDeduplication()
                    }
                    .listRowBackground(Color.blue.opacity(0.3))
                    
                    Button("清空去重测试结果") {
                        deduplicationTestManager.clearResults()
                    }
                    .listRowBackground(Color.gray.opacity(0.3))
                    
                    if !deduplicationTestManager.testResults.isEmpty {
                        ForEach(deduplicationTestManager.testResults, id: \.self) { result in
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                
                // MARK: - 请求重试测试区域
                Section("请求重试测试") {
                    Button("指数退避重试测试") {
                        retryTestManager.testExponentialBackoffRetry()
                    }
                    .disabled(retryTestManager.isTestingExponential)
                    .listRowBackground(Color.green.opacity(0.3))
                    
                    Button("快速重试测试") {
                        retryTestManager.testFastRetry()
                    }
                    .disabled(retryTestManager.isTestingFast)
                    .listRowBackground(Color.green.opacity(0.3))
                    
                    Button("自定义重试测试") {
                        retryTestManager.testCustomRetry()
                    }
                    .disabled(retryTestManager.isTestingCustom)
                    .listRowBackground(Color.green.opacity(0.3))
                    
                    Button("无重试对比测试") {
                        retryTestManager.testNoRetry()
                    }
                    .listRowBackground(Color.green.opacity(0.3))
                    
                    Button("重试+缓存测试") {
                        retryTestManager.testRetryWithCache()
                    }
                    .listRowBackground(Color.green.opacity(0.3))
                    
                    Button("重试性能对比") {
                        retryTestManager.testRetryPerformanceComparison()
                    }
                    .listRowBackground(Color.green.opacity(0.3))
                    
                    Button("清空重试测试结果") {
                        retryTestManager.clearResults()
                    }
                    .listRowBackground(Color.gray.opacity(0.3))
                    
                    if !retryTestManager.testResults.isEmpty {
                        ForEach(retryTestManager.testResults, id: \.self) { result in
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                }


                Button("请求短信(带缓存)") {
                    Task {
                        do {
                            let req = Login.sendSMS("300343", tmpLogin: false)
                            let stream: AsyncThrowingStream<NtkResponse<CodeData>, any Error> = await DefaultCoo.with(req, validation: req).startRpcWithCache()
                            for try await response in stream {
                                let codeResult: CodeData = response.data
                                if response.isCache {
                                    print("收到缓存短信: \(codeResult)")
                                } else {
                                    print("收到网络短信: \(codeResult)")
                                }
                            }
                        } catch {
                            print("短信(带缓存)发送失败 \(error)")
                        }
                    }
                    print("startRpc task ")
                }
                .listRowInsets(.none)
                .listRowBackground(Color.orange)
                
                cell("获取服务器时间")
                    .onTapGesture {
                        loadTime()
                    }
                    .listRowInsets(.none)
                    .listRowBackground(Color.orange)
                
                
            }
            .listStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.pink)
    }
    
    @ViewBuilder
    func cell(_ title: String) -> some View {
        ZStack {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                Spacer()
                Text(">")
                    .font(.system(size: 24))
            }
        }
        .background(Color.red)
        .listRowInsets(EdgeInsets()) // 去除List的默认行内边距
    }
}

// MARK: - SwiftUI Preview
struct ExampleSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        ExampleSwiftUIView()
    }
}
