/**
 * 接口数据缓存时：元数据
 *
 * @author Coo 2963460@qq.com
 * @since 2024−12-22
 *
 * Copyright © Coo.2024−{2024}. All rights reserved.
 */

export class NtkCacheMeta {
  // 缓存数据版本号
  appVersion: string;
  // 缓存构建日期
  creationDate: number;
  // 缓存过期时间
  expirationDate: number;
  // 缓存数据
  data: string | ArrayBuffer | object;

  constructor(appVersion: string, creationDate: number, expirationDate: number, data: string | object | ArrayBuffer) {
    this.appVersion = appVersion;
    this.creationDate = creationDate;
    this.expirationDate = expirationDate;
    this.data = data;
  }
}