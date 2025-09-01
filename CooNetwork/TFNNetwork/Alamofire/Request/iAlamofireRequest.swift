//
//  iAlamofireRequest.swift
//  TAIChat
//
//  Created by 李奇奇 on 2025/8/6.
//

import Foundation
import Alamofire

/// Alamofire专用请求协议，继承自iTFNRequest
/// 为使用Alamofire的请求提供更精细的配置控制
protocol iAlamofireRequest: iTFNRequest {
    
    // MARK: - Alamofire特定配置
    
    /// 参数编码方式
    /// 允许每个接口单独配置编码方式（JSON、URL、自定义等）
    var encoding: ParameterEncoding { get }
    
    /// 请求验证规则
    /// 自定义HTTP状态码验证逻辑
    var validation: DataRequest.Validation? { get }
    
    /// 请求重试策略
    /// 配置失败重试逻辑
    var retryPolicy: RetryPolicy? { get }
    
    /// 请求拦截器
    /// 用于请求/响应的预处理和后处理
    var interceptor: RequestInterceptor? { get }
    
    /// 响应缓存策略
    /// Alamofire层面的缓存控制
    var cacheResponse: CachedResponseHandler? { get }
    
    /// 请求修饰器
    /// 在发送前对URLRequest进行最后修改
    var requestModifier: Session.RequestModifier? { get }
}

// MARK: - 默认实现
extension iAlamofireRequest {
    
    /// 默认使用JSON编码（POST/PUT/PATCH）或URL编码（GET）
    var encoding: ParameterEncoding {
        URLEncoding.default
    }
    
    /// 默认验证200-299状态码
    var validation: DataRequest.Validation? {
        return nil // 使用Alamofire默认验证
    }
    
    /// 默认不重试
    var retryPolicy: RetryPolicy? {
        return nil
    }
    
    /// 默认无拦截器
    var interceptor: RequestInterceptor? {
        return nil
    }
    
    /// 默认无缓存处理
    var cacheResponse: CachedResponseHandler? {
        return nil
    }
    
    /// 默认无请求修饰
    var requestModifier: Session.RequestModifier? {
        return nil
    }
}
