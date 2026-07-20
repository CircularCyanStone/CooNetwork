//
//  EWNetworkDiagnosticsViewController.swift
//  ShangHangEWork
//
//  Created by MacBook Pro on 2026/3/8.
//  Copyright © 2026 Alibaba. All rights reserved.
//

import UIKit
import SwiftUI

class EWNetworkDiagnosticsViewController: UIViewController {
    
    private var needsStartReachability = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if EWNetworkReachabilityManager.shared.isRunning {
            EWNetworkReachabilityManager.shared.stopMonitoring()
            needsStartReachability = true
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if needsStartReachability {
            EWNetworkReachabilityManager.shared.startMonitoring()
            needsStartReachability = false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
    }
    
    private func initUI() {
        self.title = "网络诊断"
        self.view.backgroundColor = .white
        
        let hostingController = UIHostingController(rootView: EWNetworkDiagnosticsView())
        hostingController.view.backgroundColor = .white
        self.addChild(hostingController)
        self.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }
    }
}

private struct EWNetworkDiagnosticsView: View {
    
    @ObservedObject private var viewModel = EWNetworkDiagnosticsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TitleHeader(title: "基本信息")
                
                VStack(spacing: 0) {
                    let numberOfColumns = 4
                    let numberOfRows = viewModel.basicInfoArr.count / numberOfColumns + (viewModel.basicInfoArr.count % numberOfColumns == 0 ? 0 : 1)
                    
                    ForEach(0..<numberOfRows, id: \.self) { i in
                        HStack(alignment: .top, spacing: 0) {
                            let startIndex = i * numberOfColumns
                            let endIndex = (startIndex + numberOfColumns) > viewModel.basicInfoArr.count ? viewModel.basicInfoArr.count - 1 : startIndex + numberOfColumns - 1
                            
                            ForEach(viewModel.basicInfoArr[startIndex...endIndex], id: \.0) { info in
                                BasicInfoCell(title: info.0, detail: info.1).frame(maxWidth: .infinity)
                            }
                            
                            if startIndex + numberOfColumns > viewModel.basicInfoArr.count {
                                let numberOfSpacers = startIndex + numberOfColumns - viewModel.basicInfoArr.count
                                ForEach(0..<numberOfSpacers, id: \.self) {_ in
                                    Spacer().frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 167 / 255.0, green: 175 / 255.0, blue: 191 / 255.0), lineWidth: 0.5))
                .padding(15)
                
                TitleHeader(title: "网络诊断")
                
                VStack(spacing: 0) {
                    if viewModel.isNetworkConnected {
                        HStack {
                            Text("IPV4:\(viewModel.publicIPV4 ?? "")")
                                .font(.custom("PingFangSC-Regular", size: 14))
                                .foregroundColor(Color(red: 105 / 255.0, green: 113 / 255.0, blue: 132 / 255.0))
                            Spacer()
                        }
                        
                        HStack {
                            Text("IPV6:\(viewModel.publicIPV6 ?? "")")
                                .font(.custom("PingFangSC-Regular", size: 14))
                                .foregroundColor(Color(red: 105 / 255.0, green: 113 / 255.0, blue: 132 / 255.0))
                            Spacer()
                        }
                        
                        ForEach(viewModel.rpcDiagInfoArr, id: \.0) { info in
                            HStack {
                                Text("\(info.0):\(info.1)")
                                    .font(.custom("PingFangSC-Regular", size: 14))
                                    .foregroundColor(Color(red: 105 / 255.0, green: 113 / 255.0, blue: 132 / 255.0))
                                Spacer()
                            }
                        }
                    } else {
                        HStack {
                            Text("诊断已结束，网络连接失败，请检查网络设置。")
                                .font(.custom("PingFangSC-Regular", size: 14))
                                .foregroundColor(Color(red: 255 / 255.0, green: 105 / 255.0, blue: 58 / 255.0))
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 242 / 255.0, green: 78 / 255.0, blue: 77 / 255.0, opacity: 0.1)))
                            Spacer()
                        }
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 50, trailing: 0))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(15)
                
                TitleHeader(title: "域名诊断")
                
                VStack(spacing: 15) {
                    if viewModel.isNetworkConnected {
                        VStack {
                            ForEach(viewModel.domain1DiagInfoArr, id: \.0) { info in
                                HStack {
                                    Text("\(info.0):\(info.1)")
                                        .font(.custom("PingFangSC-Regular", size: 14))
                                        .foregroundColor(Color(red: 105 / 255.0, green: 113 / 255.0, blue: 132 / 255.0))
                                    Spacer()
                                }
                            }
                        }
                        
                        VStack {
                            ForEach(viewModel.domain2DiagInfoArr, id: \.0) { info in
                                HStack {
                                    Text("\(info.0):\(info.1)")
                                        .font(.custom("PingFangSC-Regular", size: 14))
                                        .foregroundColor(Color(red: 105 / 255.0, green: 113 / 255.0, blue: 132 / 255.0))
                                    Spacer()
                                }
                            }
                        }
                        
                        VStack {
                            ForEach(viewModel.domain3DiagInfoArr, id: \.0) { info in
                                HStack {
                                    Text("\(info.0):\(info.1)")
                                        .font(.custom("PingFangSC-Regular", size: 14))
                                        .foregroundColor(Color(red: 105 / 255.0, green: 113 / 255.0, blue: 132 / 255.0))
                                    Spacer()
                                }
                            }
                        }
                    } else {
                        HStack {
                            Text("诊断已结束，网络连接失败，请检查网络设置。")
                                .font(.custom("PingFangSC-Regular", size: 14))
                                .foregroundColor(Color(red: 255 / 255.0, green: 105 / 255.0, blue: 58 / 255.0))
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 242 / 255.0, green: 78 / 255.0, blue: 77 / 255.0, opacity: 0.1)))
                            Spacer()
                        }
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 50, trailing: 0))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(15)
            }
        }
        .background(Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        Button {
            let success = viewModel.copyAllInfo()
            DTContextGet().currentVisibleViewController().view.makeToast(success ? "复制成功" : "复制失败")
        } label: {
            Spacer()
            Text("复制到剪贴板")
                .font(.custom("PingFangSC-Regular", size: 16))
                .foregroundColor(Color.white)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 72 / 255.0, green: 149 / 255.0, blue: 250 / 255.0)))
        .padding(15)
    }
    
    private struct TitleHeader: View {
        
        let title: String
        
        var body: some View {
            HStack() {
                Text(title)
                    .font(.custom("PingFangSC-Regular", size: 16))
                    .foregroundColor(Color(red: 30 / 255.0, green: 31 / 255.0, blue: 34 / 255.0))
                Spacer()
            }
            .padding(15)
            .background(Color(red: 246 / 255.0, green: 246 / 255.0, blue: 246 / 255.0))
            .frame(maxWidth: .infinity)
        }
    }
    
    private struct BasicInfoCell: View {
        
        let title: String
        let detail: String
        
        var body: some View {
            VStack(spacing: 3) {
                Text(title)
                    .font(.custom("PingFangSC-Regular", size: 16))
                    .foregroundColor(Color(red: 30 / 255.0, green: 31 / 255.0, blue: 34 / 255.0))
                    .multilineTextAlignment(.center)
                
                Text(detail)
                    .font(.custom("PingFangSC-Regular", size: 14))
                    .foregroundColor(Color(red: 105 / 255.0, green: 113 / 255.0, blue: 132 / 255.0))
                    .multilineTextAlignment(.center)
            }
            .padding(7)
            .background(Color.white)
        }
    }
}
