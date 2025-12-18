#!/bin/bash

#  RunCommonPackFramework.sh
#  siku_common
#
#  Created by 李奇奇 on 2025/12/12.
#
#  文件功能描述:
#  以固定参数调用 CommonPackFramework.sh 执行 XCFramework 打包流程，
#  简化用户操作，统一入口与默认构建配置。
#
#  类型功能描述:
#  Shell 脚本，零依赖包装调用；通过绝对路径执行目标脚本并传入固定参数。

set -e

bash \
  "/Users/coo/Desktop/SiKu/subs/scripts/CommonPackFramework.sh" \
  -p CooNetwork \
  -s CooNetwork \
  -c Release

