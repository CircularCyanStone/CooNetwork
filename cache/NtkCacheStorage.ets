/**
 * Ntk网络缓存工具：缓存功能的抽象类
 *
 * @author Coo 2963460@qq.com
 * @since 2024−12-22
 *
 * Copyright © Coo.2024−{2024}. All rights reserved.
 */
import { iNtkRequest } from '../iNtk/iNtkRequest';
import { NtkCacheMeta } from './NtkCacheMeta';

export abstract class NtkCacheStorage {
  readonly request: iNtkRequest;

  constructor(request: iNtkRequest) {
    this.request = request;
  }

  async setData(metaData: NtkCacheMeta, key: string): Promise<boolean> {
    throw new Error('sub class should implement this method')
  }

  async getData(key: string): Promise<NtkCacheMeta | undefined> {
    throw new Error('sub class should implement this method')
  }

  hasData(key: string): boolean {
    throw new Error('sub class should implement this method')
  }
}
