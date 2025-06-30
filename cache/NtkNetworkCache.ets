/**
 * Ntk网络工具缓存工具
 * 抽象逻辑
 *
 * @author Coo 2963460@qq.com
 * @since 2024−12-22
 *
 * Copyright © Coo.2024−{2024}. All rights reserved.
 */
import { NtkCacheMeta as NtkCacheMeta } from "./NtkCacheMeta";
import { doMd5, doMd5Sync } from "./NtkMd5";
import { NtkCacheStorage } from "./NtkCacheStorage";
import { bundleManager } from "@kit.AbilityKit";
import { systemDateTime } from "@kit.BasicServicesKit";
import { NtkCacheKeyManager } from "./NtkCacheKeyManager";
import { iNtkRequest } from "../iNtk/iNtkRequest";


export class NtkNetworkCache {
  readonly request: iNtkRequest;
  readonly storage: NtkCacheStorage;

  constructor(request: iNtkRequest, storage: NtkCacheStorage) {
    this.request = request;
    this.storage = storage
  }

  /**
   * 构建缓存时key
   * @returns key
   */
  private async createCacheKey(): Promise<string> {
    return NtkCacheKeyManager.shared.getCacheKey(this.request);
  }

  private createCacheKeySync(): string {
    let parameter: string | Object | ArrayBuffer | undefined = '';
    if (this.request.content) {
      if (this.request.cacheConfig && this.request.cacheConfig.filterParameter) {
        parameter = this.request.cacheConfig.filterParameter(this.request.content);
      } else {
        parameter = this.request.content;
      }
    }
    let keyInfo: string = `method:${this.request.method}|url:${this.request.url}|args:${parameter}`;
    let md5Key = doMd5Sync(keyInfo);
    return md5Key
  }

  /**
   * 返回该请求是否有缓存数据
   * @returns
   */
  hasData(): boolean {
    let cacheKey = this.createCacheKeySync();
    return this.storage.hasData(cacheKey);
  }

  /**
   * 读取request关联的缓存数据
   */
  async loadData(): Promise<string | object | ArrayBuffer | undefined> {
    let cacheKey = await this.createCacheKey();
    let cacheData = await this.storage.getData(cacheKey)
    if (cacheData && cacheData.expirationDate < systemDateTime.getTime()) {
      // 过期了
      return undefined;
    }
    return cacheData?.data
  }

  /**
   * 缓存接口数据
   * @param data 接口返回的数据
   */
  async save(data: string | object | ArrayBuffer): Promise<boolean> {
    let cacheKey = await this.createCacheKey();
    return this._save(data, cacheKey)
  }

  private async _save(data: string | object | ArrayBuffer, key: string) {
    if (!this.request.cacheConfig) {
      return false;
    }
    if (!data) {
      return false;
    }
    let bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
    let versionName = bundleInfo.versionName;
    let createTime = systemDateTime.getTime();
    let expirationDate = createTime + this.request.cacheConfig.cacheTime
    let metaData = new NtkCacheMeta(versionName, createTime, expirationDate, data);

    return this.storage.setData(metaData, key);
  }
}