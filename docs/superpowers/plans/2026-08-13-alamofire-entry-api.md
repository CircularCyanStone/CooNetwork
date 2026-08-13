# Alamofire Entry API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a typed Alamofire assembly configuration and migrate callers while preserving deprecated source-compatible entry points.

**Architecture:** A response-typed configuration owns client, parser strategy, and cache storage. Parser strategy factories erase concrete response-key and decoder types after constructing the core parser, keeping standard-pipeline options separate from complete custom parser replacement.

**Tech Stack:** Swift 6.1, Swift Package Manager, Alamofire 5.10, Swift Testing

---

### Task 1: Characterization and New Interface Tests

**Files:**
- Create: `Tests/CooNetworkTests/NtkAFConfigurationTests.swift`

- [x] Write compile-time and behavior tests for `.default`, `.standard`, `.custom`, injected client, cache storage, and upload behavior.
- [x] Run `swift test --filter NtkAFConfigurationTests` and confirm failure because the new public types and entry do not exist.

### Task 2: Typed Alamofire Assembly

**Files:**
- Create: `Sources/AlamofireClient/NtkAFConfiguration.swift`
- Modify: `Sources/AlamofireClient/Ntk+AF.swift`

- [x] Implement `NtkAFParsingStrategy<ResponseData>` factories for the default decoder and a custom decoder.
- [x] Implement `NtkAFConfiguration<ResponseData>` with default client, standard parser, and optional cache storage.
- [x] Implement `Ntk.alamofire(_:configuration:)` and centralize network assembly/upload policy in one private helper.
- [x] Mark legacy parameter-based `withAF` overloads deprecated without changing their behavior.
- [x] Run the focused tests until green.

### Task 3: Documentation and Examples

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `Sources/AlamofireClient/CLAUDE.md`
- Modify: `Examples/PodExample/PodExample/**/*.swift`
- Modify: `Tests/CooNetworkTests/CooNetworkTests.swift`
- Modify: `Tests/CooNetworkTests/AFClientUploadTests.swift`

- [x] Replace framework-owned sample calls with `alamofire(_:configuration:)`.
- [x] Express custom parser replacement through `.custom(...)` and standard validation through `.standard(...)`.
- [x] Document default, standard-pipeline, custom-parser, and custom-session examples.

### Task 4: Verification

**Files:**
- Modify only files required by compiler or test findings.

- [x] Run `swift test` and resolve all failures introduced by the change.
- [x] Run `swift build` and confirm the package builds without errors.
- [x] Inspect `git diff --check` and the final diff for unintended changes.
