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
inhibit_all_warnings!

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

    post_install do |installer|
      installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
        end
      end
    end

end
