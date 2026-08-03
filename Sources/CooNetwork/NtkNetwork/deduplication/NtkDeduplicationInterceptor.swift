//
//  NtkDeduplicationInterceptor.swift
//  NtkNetwork
//
//  Created by 李奇奇 on 2025/9/2.
//

import Foundation

struct NtkDeduplicationInterceptor: iNtkInterceptor {

    /// 去重必须包在整个执行链外层，才能让命中同一 key 的调用共享网络、重试、解析后的最终结果。
    var priority: NtkInterceptorPriority { .outerHighest }

    /// 把执行器冻结的去重 key 和有效超时交给任务管理器。
    ///
    /// `deduplicationKey` 非空且已有相同任务时，本次调用等待该任务并取得同类型结果；没有相同
    /// 任务时创建新任务。key 为空时任务管理器按请求实例 UUID 隔离，仍负责超时和取消，但不会
    /// 与其他调用共享。这里不根据 request 重新计算 key，避免与缓存或执行器使用不同字段规则。
    func intercept(context: NtkInterceptorContext, next: iNtkRequestHandler) async throws -> any iNtkResponse {
        try await NtkTaskManager.shared.executeWithDeduplication(
            request: context.request,
            deduplicationKey: context.deduplicationKey,
            effectiveTimeout: context.effectiveTimeout
        ) {
            try await next.handle(context: context)
        }
    }

}
