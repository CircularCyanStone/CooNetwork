# mPaaS Pods Begin
plugin "cocoapods-mPaaS"
source "https://gitee.com/mpaas/podspecs.git"
source 'https://gitee.com/mirrors/CocoaPods-Specs'
#source 'https://github.com/volcengine/volcengine-specs.git'

mPaaS_baseline '10.2.3'  # 请将 x.x.x 替换成真实基线版本
mPaaS_version_code 63   # This line is maintained by MPaaS plugin automatically. Please don't modify.
# mPaaS Pods End
# ---------------------------------------------------------------------
# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'CooNetwork' do
  use_frameworks!
  mPaaS_pod "mPaaS_MobileFramework"
  mPaaS_pod "mPaaS_RPC"
  mPaaS_pod "mPaaS_DataCenter"
  mPaaS_pod "mPaaS_MobileFramework"
  
    pod 'CodableWrappers'
    pod 'Alamofire'
    pod 'Moya'
    pod 'AFNetworking'
    pod 'SVProgressHUD'
    pod 'Toast-Swift'
#    pod 'YYModel'
#    pod 'MJExtension'
end
