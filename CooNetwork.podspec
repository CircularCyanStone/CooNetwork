Pod::Spec.new do |s|
  s.name             = 'CooNetwork'
  s.version          = '0.0.13'
  s.summary          = '统一的网络工具，支持接入不同的网络组件，提供统一的API与业务层对接。'
  s.description      = <<-DESC
                       CooNetwork 是一个统一的网络工具库，旨在为不同的网络组件提供统一的接入方式，
                       方便业务层对接和使用。
                       DESC

  s.homepage         = 'https://github.com/CircularCyanStone/CooNetwork'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'coocy' => '2963460@qq.com' }
  s.source           = { :git => 'https://github.com/CircularCyanStone/CooNetwork.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.7'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |core|
    core.source_files = 'Sources/CooNetwork/**/*.{swift, h, m}'
  end

  s.subspec 'Alamofire' do |af|
    af.source_files = 'Sources/AlamofireClient/**/*.{swift, h, m}'
    af.dependency 'CooNetwork/Core'
    af.dependency 'Alamofire', '~> 5.10'
  end
end
