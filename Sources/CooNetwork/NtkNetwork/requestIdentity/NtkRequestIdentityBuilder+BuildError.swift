extension NtkRequestIdentityBuilder {

    /// 标识请求 key 构建失败发生在哪个部分，供统一的脱敏日志使用。
    enum Section: String, Sendable {
        /// 请求 Header，包括 Header 转换闭包的输入输出。
        case headers
        /// 请求参数，包括参数转换闭包和递归参数值。
        case parameters
        /// 只写入本地请求 key 的附加 key/value；当前 value 被约束为 String。
        case requestIdentityValues
    }

    /// 请求 key 无法被稳定构建时使用的内部错误。
    ///
    /// 这些错误不属于网络请求失败：`NtkNetworkExecutor` 捕获后会把 request identity 置为 nil，跳过
    /// 本次缓存读写与去重，但仍把原始请求交给 client。错误关联值只保存结构路径和动态类型，
    /// 不保存参数值、Header value 或自定义错误描述，避免 warning 日志泄露凭证。
    enum BuildError: Error, Sendable, Equatable {
        /// 参数树中出现编码器白名单外的 `Sendable` 类型，无法保证跨运行稳定表示。
        case unsupportedValue(path: String, type: String)
        /// Float、Double 或 Date 的底层时间值为 NaN/Infinity，无法作为稳定资源维度。
        case nonFiniteValue(path: String, type: String)
        /// 业务转换闭包抛错；只保留错误类型，不保留可能含敏感数据的错误消息。
        case transformationFailed(section: Section, errorType: String)
        /// Header 或转换闭包输出了不符合 HTTP token 字符规则的名称。
        case invalidHeaderName(String)
        /// 两个 Header key 在转成小写后代表同一逻辑字段，结果依赖字典遍历顺序，故拒绝构建。
        case duplicateHeaderName(String)
        /// 转换闭包输出与显式 `.include` 字段同名；框架拒绝猜测覆盖优先级。
        case keyConflict(section: Section, key: String)

        /// 生成允许写入日志的脱敏诊断。
        ///
        /// 文本用于定位失败类别和结构位置，不输出失败值，也不调用底层 error 的 description。
        var logMessage: String {
            switch self {
            case .unsupportedValue(let path, let type):
                return "unsupported value at \(path) (type: \(type))"
            case .nonFiniteValue(let path, let type):
                return "non-finite value at \(path) (type: \(type))"
            case .transformationFailed(let section, let errorType):
                return "transformation failed in \(section.rawValue) (error type: \(errorType))"
            case .invalidHeaderName(let name):
                return "invalid header name at headers.\(name)"
            case .duplicateHeaderName(let name):
                return "duplicate header name at headers.\(name)"
            case .keyConflict(let section, let key):
                return "request identity conflict in \(section.rawValue).\(key)"
            }
        }
    }
}
