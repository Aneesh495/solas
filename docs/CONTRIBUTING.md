# Contributing to Solas

Thank you for your interest in contributing to Solas. As a high-performance WebRTC Selective Forwarding Unit engineered in Vala and compiled directly to native C, we maintain strict engineering and architectural standards.

---

## 1. Development Environment Setup

### System Prerequisites
- **Vala Compiler**: `valac` version 0.56 or higher
- **Build System**: `meson` 1.0+ and `ninja`
- **C Compiler**: Clang 15+ or GCC 11+
- **Libraries**:
  - GLib / GObject / GIO 2.68+
  - Libgee 0.8+
  - JSON-GLib 1.0+
  - OpenSSL 3.0+

### Building and Testing
```bash
# Setup build directory
meson setup build --buildtype=debugoptimized

# Compile all binaries and test suites
ninja -C build

# Execute full automated test suite
ninja -C build test

# Run deterministic protocol fuzzing suite
./build/test_fuzz
```

---

## 2. Coding & Architectural Standards

### Vala & GObject Memory Conventions
1. **Ownership Semantics**:
   - Return owned objects (`ByteBuffer`, `RtpPacket`) across module boundaries.
   - Use `unowned` for internal non-allocating string and buffer views to avoid redundant reference count increments.
2. **Error Handling**:
   - Use strongly typed Vala `errordomain` declarations for all protocol-level failures (e.g. `RtpError`, `StunError`, `SFrameError`).
   - Never silence exceptions without explicit logging or graceful recovery.
3. **Buffer Management**:
   - Use `Solas.Core.ByteBuffer` and `Solas.Core.SlabPool` for all packet paths.
   - Do not perform ad-hoc `malloc` allocations on the hot packet forwarding loop.

### Character Set & Formatting Compliance
- **Zero Em Dashes**: Never use em dashes or en dashes anywhere in code, comments, commit messages, or documentation. Use hyphens, colons, or parentheses instead.
- Run the compliance check before submitting patches:
  ```bash
  python3 scripts/check_no_em_dashes.py
  ```

---

## 3. Submitting Changes

1. Fork the repository and create a feature branch from `main`.
2. Ensure all unit and integration tests pass with 0 failures:
   ```bash
   meson test -C build --print-errorlogs
   ```
3. Follow the Conventional Commits specification:
   - `feat(scope): ...`
   - `fix(scope): ...`
   - `test(scope): ...`
   - `docs(scope): ...`
   - `build(scope): ...`
4. Open a pull request against `main` with a clear explanation of changes, RFC standards referenced, and performance impact.
