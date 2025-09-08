import Foundation

/// TFN数据解析拦截器
struct TFNDataParsingInterceptor<DataModel: Sendable & Decodable, Keys: iTFNResponseMapKeys>: iTFNInterceptor {
    /// 数据解析拦截器使用最低优先级，确保在所有其他处理完成后最后执行数据解析
    var priority: TFNInterceptorPriority { .lowest }

    func intercept(_ context: TFNInterceptorContext, next: TFNNextHandler) async throws -> any iTFNResponse {
        let response = try await next.proceed(context)
        guard let dataResponse = response as? TFNDataResponse else {
            if response is TFNResponse<DataModel> { return response }
            throw TFNError.responseTypeMismatch(response)
        }
#if DEBUG
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: dataResponse.data)
            if !dataResponse.isCache {
                print("DEBUG [TFNNetwork] response json object \(jsonObject)")
            }
        } catch {
            print("DEBUG [TFNNetwork] response json error \(error) 缓存：\(dataResponse.isCache)")
        }
#endif
        do {
            let decoderResponse = try JSONDecoder().decode(TFNResponseDecoder<DataModel?, Keys>.self, from: dataResponse.data)
            
            var tfnResponse: TFNResponse<DataModel>? = nil
            if DataModel.self is TFNNever.Type {
                tfnResponse = TFNResponse<DataModel>(
                    code: decoderResponse.code,
                    data: TFNNever() as! DataModel,
                    msg: decoderResponse.msg,
                    response: dataResponse.response,
                    request: dataResponse.request
                )
            }else {
                if let data = decoderResponse.data {
                    tfnResponse = TFNResponse<DataModel>(
                        code: decoderResponse.code,
                        data: data,
                        msg: decoderResponse.msg,
                        response: dataResponse.response,
                        request: dataResponse.request
                    )
                }else {
                    let tfnResponse = TFNResponse<DataModel?>(
                        code: decoderResponse.code,
                        data: nil,
                        msg: decoderResponse.msg,
                        response: dataResponse.response,
                        request: dataResponse.request
                    )
                    let isServiceSuccess = context.mutableRequest.isServiceSuccess(tfnResponse)
                    if !isServiceSuccess {
                        // 服务端校验失败
                        throw TFNError.businessError(tfnResponse.statusCode, tfnResponse.message)
                    }else {
                        throw TFNError.responseTypeMismatch(tfnResponse)
                    }
                }
            }
            // 能走到这里，必然校验成功
            tfnResponse?.isCache = dataResponse.isCache
            if let tfnResponse {
                let isServiceSuccess = context.mutableRequest.isServiceSuccess(tfnResponse)
                if !isServiceSuccess {
                    // 服务端校验失败
                    throw TFNError.businessError(tfnResponse.statusCode, tfnResponse.message)
                }
                return tfnResponse
            }else {
                throw TFNError.unknown
            }
        } catch let error as TFNError {
            throw error
        } catch {
            print("decoder error \(error)")
            throw TFNError.decodingFailure(underlying: error)
        }
    }
}
