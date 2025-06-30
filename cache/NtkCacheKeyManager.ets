/**
 * Ntk缓存键管理工具：基于内存的缓存键复用管理
 *
 * @author Coo 2963460@qq.com
 * @since 2024−12-25
 *
 * Copyright © Coo.2024−{2024}. All rights reserved.
 *
 *
 * 建议后续步骤：
 在 NtkCacheKeyManager 中添加缓存命中率统计
 实现更智能的 LRU 淘汰策略（参考 LinkedHashMap）
 增加缓存失效机制（如定时刷新）
 */
import { iNtkRequest } from '../iNtk/iNtkRequest';
import { doMd5 } from './NtkMd5';

class NtkCacheKeyManager {
  // 单例实例
  private static _instance: NtkCacheKeyManager;
  // 内存缓存（LRU容量建议100）
  private cacheMap: Map<string, string> = new Map();

  private constructor() {
  }

  static get shared(): NtkCacheKeyManager {
    if (!NtkCacheKeyManager._instance) {
      NtkCacheKeyManager._instance = new NtkCacheKeyManager();
    }
    return NtkCacheKeyManager._instance;
  }

  /**
   * 获取缓存键（线程安全）
   */
  async getCacheKey(request: iNtkRequest): Promise<string> {
    const serialized = this.serializeRequest(request);

    // 内存缓存命中
    if (this.cacheMap.has(serialized)) {
      return this.cacheMap.get(serialized)!;
    }

    // 计算新缓存键
    const newKey = await this.generateKey(serialized);
    this.updateCache(serialized, newKey);
    return newKey;
  }

  /**
   * 序列化请求参数（私有方法）
   */
  private serializeRequest(request: iNtkRequest): string {
    let parameter: string | object | ArrayBuffer | undefined = '';
    if (request.content) {
      if (request.cacheConfig && request.cacheConfig.filterParameter) {
        parameter = request.cacheConfig.filterParameter(request.content);
      } else {
        parameter = request.content;
      }
    }
    return JSON.stringify({
      method: request.method,
      url: request.url,
      params: parameter
    });
  }

  /**
   * 生成哈希键（私有方法）
   */
  private async generateKey(serialized: string): Promise<string> {
    return doMd5(serialized);
  }

  /**
   * 更新缓存（带LRU淘汰）
   */
  private updateCache(key: string, value: string): void {
    if (this.cacheMap.size >= 100) {
      // 删除最旧条目（实际生产环境应用更复杂策略）
      const firstKey = this.cacheMap.keys().next().value as string;
      this.cacheMap.delete(firstKey);
    }
    this.cacheMap.set(key, value);
  }
}

export { NtkCacheKeyManager };
