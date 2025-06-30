/**
 * Md5加密
 *
 * @author Coo 2963460@qq.com
 * @since 2024−12-22
 *
 * Copyright © Coo.2024−{2024}. All rights reserved.
 */

import { buffer } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

function stringToUint8Array(str: string) {
  return new Uint8Array(buffer.from(str, 'utf-8').buffer);
}

/**
 * 对字符串进行md5处理
 * @param bodyStr 待处理的字符串
 */
export async function doMd5(bodyStr: string) {
  let mdAlgName = 'MD5';
  let md = cryptoFramework.createMd(mdAlgName);
  let promiseMdUpdate = md.update({ data: stringToUint8Array(bodyStr) });
  let result = await promiseMdUpdate
    .then(() => {
      let digestResult = md.digest();
      return digestResult;
    })
    .then(digestOutput => {
      let mdOutput = digestOutput;
      let buf = buffer.from(mdOutput.data).toString('hex');
      return buf
    });
  return result
}

export function doMd5Sync(bodyStr: string) {
  let mdAlgName = 'MD5';
  let md = cryptoFramework.createMd(mdAlgName);
  md.updateSync({ data: stringToUint8Array(bodyStr) });
  let digestResult = md.digestSync();
  let buf = buffer.from(digestResult.data).toString('hex');
  return buf
}