//
//  NtkInterceptorOrdering.swift
//  CooNetwork
//

import Foundation

/// 统一定义 interceptor 的请求流顺序。
enum NtkInterceptorOrdering {
    static func sorted(
        _ interceptors: [iNtkInterceptor]
    ) -> [iNtkInterceptor] {
        interceptors.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.priority == rhs.element.priority {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.priority > rhs.element.priority
            }
            .map { $0.element }
    }
}
