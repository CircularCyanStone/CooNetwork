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
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - SwiftUI View
struct ExampleSwiftUIView: View {
    @State private var counter = 0
    @State private var text = "Hello SwiftUI!"
    
    private func loadTime() {
        Task {
            do {
                let response: Int = try await DefaultCoo.with(Login.getTime).startRpc().data
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
                Button("actor测试") {
                    let actorExample = CooActorExample()
                    Task {
                        await actorExample.modifyName("ccc")
                        await actorExample.changeSchool()
                    }
                }
                .listRowInsets(.none)
                .listRowBackground(Color.orange)

                
                Button("请求短信") {
                    Task {
                        do {
                            let req = Login.sendSMS("300343", tmpLogin: false)
                            
                            let cacheData: CodeData? = try await DefaultCoo.with(req).loadRpcCache()?.data
                            
                            
                            let codeResult: CodeData = try await DefaultCoo.with(req).startRpc(req).data
                            print("短信发送成功")
                        }catch {
                            print("短信发送失败 \(error)")
                        }
                    }
                }
                .listRowInsets(.none)
                .listRowBackground(Color.orange)


                Button("请求短信(带缓存)") {
                    Task {
                        do {
                            let req = Login.sendSMS("300343", tmpLogin: false)
                            let stream: AsyncThrowingStream<NtkResponse<CodeData>, Error> = await DefaultCoo.with(req).startRpcWithCache()
                            for try await response in stream {
                                let codeResult: CodeData = response.data
//                                if response.isCache {
//                                    print("收到缓存短信: \(codeResult)")
//                                } else {
//                                    print("收到网络短信: \(codeResult)")
//                                }
                            }
                            print("短信处理完成")
                        } catch {
                            print("短信(带缓存)发送失败 \(error)")
                        }
                    }
                }
                .listRowInsets(.none)
                .listRowBackground(Color.orange)
                
                
                Button("获取服务器时间") {
                    loadTime()
                }
                .listRowInsets(.none)
                .listRowBackground(Color.orange)
                
            }
            .listStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.pink)
    }
}

// MARK: - SwiftUI Preview
struct ExampleSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        ExampleSwiftUIView()
    }
}
