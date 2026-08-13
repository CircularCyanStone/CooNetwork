# Alamofire Entry API Design

## Goal

Modernize the Alamofire request entry without breaking existing `withAF` callers. The new interface must expose the current parsing pipeline, support injected `AFClient` instances, and prevent configurations whose arguments are silently ignored.

## Interface

`NtkAFConfiguration<ResponseData>` owns the Alamofire client, parsing strategy, and optional cache storage for one request construction. `NtkAFParsingStrategy<ResponseData>` exposes two mutually exclusive factories:

- `standard(...)` constructs `NtkDataParsingInterceptor` from response keys, validation, hooks, transformers, and an optional custom decoder.
- `custom(_:)` installs a complete caller-provided `iNtkResponseParser` and accepts no separate parsing options.

`Ntk.alamofire(_:configuration:)` is the long-term entry point. The zero-configuration form retains the existing default client, response keys, validation, cache, and upload deduplication behavior.

## Compatibility

Both existing parameter-based `withAF` overloads remain available for one compatibility cycle and are marked deprecated. Their runtime behavior remains unchanged, including request-provided validation fallback. New code does not infer response validation from the request type.

## Assembly Flow

1. The caller selects a typed `NtkAFConfiguration`, or uses its default value.
2. The parsing strategy has already erased the concrete keys and decoder types into `iNtkResponseParser`.
3. The entry creates `NtkNetwork` through the core `Ntk.with` interface.
4. Cache storage is translated into the existing cache interceptor by the core factory.
5. Upload requests have deduplication disabled as before.

## Verification

Tests cover default construction, injected client/session behavior, standard parser hooks and transformers, custom decoder construction, custom parser selection, upload deduplication, and source compatibility of deprecated overloads. README examples and repository samples migrate to the new entry.
