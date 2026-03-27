//
//  iNtkResponseValidation.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/6/19.
//

import Foundation

/// 响应业务成功判定协议。
///
/// 该协议不负责解析 payload，也不直接参与 parser 的阶段编排；
/// 它的职责是在解析策略已经构造出 `NtkResponse` 之后，判断该响应在业务语义上是否应被视为成功。
///
/// 设计目的：
/// - 将“协议能否被解释”与“业务是否成功”拆开
/// - 允许不同接口族复用同一套 parsing pipeline，但使用不同的业务成功标准
/// - 让 `NtkDefaultResponseParsingPolicy` 在保持裁决中心地位的同时，把业务成功规则委托给更聚焦的 checker
///
/// 边界说明：
/// - 它只回答“这个响应是否业务成功”，不回答“解析流程接下来该怎么走”
/// - 它不创建响应对象，也不映射最终错误类型
/// - 若需要访问具体 `data` 结构，应在实现内部自行做安全类型转换
public protocol iNtkResponseValidation: Sendable {

    /// 判断一个已经构建完成的响应对象是否表示业务成功。
    ///
    /// - Parameter response: 已由 parsing policy 构建完成的响应对象。此时协议层字段已被解释完成，但最终是否放行由调用方根据布尔结果决定。
    /// - Returns: `true` 表示该响应在业务语义上可继续作为成功结果返回；`false` 表示应视为业务失败。
    func isServiceSuccess(_ response: any iNtkResponse) -> Bool

}
