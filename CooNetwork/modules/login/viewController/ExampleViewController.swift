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
            VStack {
                HStack {
                    Button("XX") {
                        
                    }
                    .background(Color.gray)
                    
                    Text("还耗")
                }
                .background(Color.secondary)
            }
            .frame(minWidth: 120, maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
            .background(Color.green)
            
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
                            
                            let cacheData: CodeData? = try await DefaultCoo.with(req).hud(true).loadCache()?.data
                            
                            
                            let codeResult: CodeData = try await DefaultCoo.with(req, validation: req).sendRequest().data
                            print("短信发送成功")
                        }catch {
                            print("短信发送失败 \(error)")
                        }
                    }
                }
                .frame(minHeight: 150)
                .listRowInsets(EdgeInsets()) // 去除List的默认行内边距
                .listRowBackground(Color.orange)


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
