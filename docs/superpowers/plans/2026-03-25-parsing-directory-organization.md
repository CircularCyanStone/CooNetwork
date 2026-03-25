# Parsing Directory Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate parsing-specific protocols, implementations, and parsing-only models into a new `NtkNetwork/parsing/` directory without changing runtime behavior.

**Architecture:** This is a directory-organization refactor, not a semantic refactor. Move only parsing feature files into a new `parsing/` directory, keep shared network models in place, then update directory docs and verify that parser, executor, integration, and full-suite behavior remain unchanged.

**Tech Stack:** Swift 6.1 / SPM, `@NtkActor`, Swift Testing framework (`import Testing`), existing `CooNetwork` / `AlamofireClient` modules

---

## File Map

| File | Change |
|------|--------|
| `Sources/CooNetwork/NtkNetwork/parsing/` | New feature directory for parsing-specific files |
| `Sources/CooNetwork/NtkNetwork/iNtk/iNtkParsingHooks.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponsePayloadDecoding.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponsePayloadTransforming.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseValidation.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/interceptor/NtkPayloadDecoders.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/interceptor/NtkParsingResult.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/interceptor/NtkDefaultResponseParsingPolicy.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/model/NtkPayload.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/model/PayloadRootGate.swift` | Move to `parsing/` |
| `Sources/CooNetwork/NtkNetwork/CLAUDE.md` | Update top-level module structure description |
| `Sources/CooNetwork/NtkNetwork/parsing/CLAUDE.md` | New directory description |
| `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md` | Remove parsing-specific ownership wording |
| `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md` | Remove parsing protocol ownership wording |
| `Sources/CooNetwork/NtkNetwork/model/CLAUDE.md` | Remove parsing-specific model ownership wording |

### Tests to rely on
- `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

---

## Task 1: Lock behavior before moving files

**Files:**
- Test: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 1.1: Run parser tests before any file moves**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: PASS.

- [ ] **Step 1.2: Run executor tests before any file moves**

Run:

```bash
swift test --filter NtkNetworkExecutorTests
```

Expected: PASS.

- [ ] **Step 1.3: Run integration tests before any file moves**

Run:

```bash
swift test --filter NtkNetworkIntegrationTests
```

Expected: PASS.

---

## Task 2: Move parsing-specific files into the new directory

**Files:**
- Create directory: `Sources/CooNetwork/NtkNetwork/parsing/`
- Move: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkParsingHooks.swift`
- Move: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponsePayloadDecoding.swift`
- Move: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponsePayloadTransforming.swift`
- Move: `Sources/CooNetwork/NtkNetwork/iNtk/iNtkResponseValidation.swift`
- Move: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDataParsingInterceptor.swift`
- Move: `Sources/CooNetwork/NtkNetwork/interceptor/NtkPayloadDecoders.swift`
- Move: `Sources/CooNetwork/NtkNetwork/interceptor/NtkParsingResult.swift`
- Move: `Sources/CooNetwork/NtkNetwork/interceptor/NtkDefaultResponseParsingPolicy.swift`
- Move: `Sources/CooNetwork/NtkNetwork/model/NtkPayload.swift`
- Move: `Sources/CooNetwork/NtkNetwork/model/PayloadRootGate.swift`

- [ ] **Step 2.1: Move the four parsing protocols into `parsing/`**

Use `mv` so git tracks renames.

- [ ] **Step 2.2: Move the four parsing implementation files into `parsing/`**

Use `mv` so git tracks renames.

- [ ] **Step 2.3: Move the two parsing-only model files into `parsing/`**

Use `mv` so git tracks renames.

- [ ] **Step 2.4: Run parser tests immediately after file moves**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: PASS. If compile errors appear, fix only path/organization fallout.

---

## Task 3: Update directory documentation to match the new layout

**Files:**
- Modify: `Sources/CooNetwork/NtkNetwork/CLAUDE.md`
- Create: `Sources/CooNetwork/NtkNetwork/parsing/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md`
- Modify: `Sources/CooNetwork/NtkNetwork/model/CLAUDE.md`

- [ ] **Step 3.1: Update top-level structure doc to include `parsing/`**

Add `parsing/` as a first-class submodule in `NtkNetwork/CLAUDE.md`.

- [ ] **Step 3.2: Create `parsing/CLAUDE.md`**

Describe the directory as the home of parsing-specific protocols, payload preparation, decoder/policy pipeline, and parsing-only models.

- [ ] **Step 3.3: Remove parsing ownership from `interceptor/CLAUDE.md`**

Keep only chain and generic interceptor responsibilities there.

- [ ] **Step 3.4: Remove parsing protocol ownership from `iNtk/CLAUDE.md`**

Keep only generic core interfaces there.

- [ ] **Step 3.5: Remove parsing-only model ownership from `model/CLAUDE.md`**

Leave only shared network models there.

---

## Task 4: Re-verify affected runtime paths

**Files:**
- Test: `Tests/CooNetworkTests/AFDataParsingInterceptorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkExecutorTests.swift`
- Test: `Tests/CooNetworkTests/NtkNetworkIntegrationTests.swift`

- [ ] **Step 4.1: Re-run parser tests**

Run:

```bash
swift test --filter NtkDataParsingInterceptorTests
```

Expected: PASS.

- [ ] **Step 4.2: Re-run executor tests**

Run:

```bash
swift test --filter NtkNetworkExecutorTests
```

Expected: PASS.

- [ ] **Step 4.3: Re-run integration tests**

Run:

```bash
swift test --filter NtkNetworkIntegrationTests
```

Expected: PASS.

---

## Task 5: Final verification and commit

- [ ] **Step 5.1: Run full test suite**

Run:

```bash
swift test
```

Expected: all tests PASS.

- [ ] **Step 5.2: Run full build**

Run:

```bash
swift build
```

Expected: `Build complete!`

- [ ] **Step 5.3: Commit the directory reorganization**

```bash
git add Sources/CooNetwork/NtkNetwork/parsing \
        Sources/CooNetwork/NtkNetwork/CLAUDE.md \
        Sources/CooNetwork/NtkNetwork/interceptor/CLAUDE.md \
        Sources/CooNetwork/NtkNetwork/iNtk/CLAUDE.md \
        Sources/CooNetwork/NtkNetwork/model/CLAUDE.md
git commit -m "refactor: consolidate parsing files into dedicated directory"
```

---

## Verification Checklist

After all tasks complete, verify:

- [ ] parsing-specific protocols, implementations, and parsing-only models are under `Sources/CooNetwork/NtkNetwork/parsing/`
- [ ] shared response/network model types remain outside `parsing/`
- [ ] no runtime semantics changed
- [ ] parser, executor, and integration subset tests pass
- [ ] `swift test` passes
- [ ] `swift build` passes
