# CooNetwork Podspec Refactoring Plan

> **For Trae:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor `CooNetwork.podspec` to support subspecs, allowing modular integration of Core and Alamofire implementation.

**Architecture:**
- **Core Subspec**: Contains the base networking logic (`Sources/CooNetwork`). Default subspec.
- **Alamofire Subspec**: Contains the Alamofire implementation (`Sources/AlamofireClient`). Depends on `Core` and `Alamofire`.

**Tech Stack:** CocoaPods, Ruby (Podspec DSL).

---

### Task 1: Update Podspec Structure

**Files:**
- Modify: `CooNetwork.podspec`

**Step 1: Backup current Podspec**

```bash
cp CooNetwork.podspec CooNetwork.podspec.bak
```

**Step 2: Update Podspec content**

Modify `CooNetwork.podspec` to use `subspec` blocks.

```ruby
Pod::Spec.new do |s|
  s.name             = 'CooNetwork'
  s.version          = '0.0.4'
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
    core.source_files = 'Sources/CooNetwork/**/*'
  end

  s.subspec 'Alamofire' do |af|
    af.source_files = 'Sources/AlamofireClient/**/*'
    af.dependency 'CooNetwork/Core'
    af.dependency 'Alamofire', '~> 5.10'
  end
end
```

**Step 3: Verify Podspec syntax**

Run: `pod ipc spec CooNetwork.podspec`
Expected: Valid JSON output representing the podspec.

### Task 2: Validate Podspec

**Files:**
- None (Running validation command)

**Step 1: Run pod lib lint**

Run: `pod lib lint CooNetwork.podspec --allow-warnings --verbose`
Expected: `CooNetwork passed validation.`

**Step 2: Clean up backup**

Run: `rm CooNetwork.podspec.bak`
