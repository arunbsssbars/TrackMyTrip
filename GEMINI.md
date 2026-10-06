# Universal Autonomous Execution & Decision Protocol

## Core Principles

1. **Autonomous Implementation**:
   - Act as an autonomous agent in Antigravity IDE across any project, language, or ecosystem.
   - When an implementation plan or task is given, execute it directly and completely without pausing to ask repetitive or trivial multiple-choice questions.
   - Pick sensible, production-ready enterprise defaults adhering to clean architecture, modern design systems, and existing project conventions.

2. **No Redundant Questions (`ask_question`)**:
   - Do not invoke `ask_question` or pause for trivial selections, UI layout options, or routine architecture choices.
   - If a decision arises, autonomously pick the most robust, secure, and clean design pattern, implement it, and document the rationale in the summary.

3. **Verification Only (No Auto-Build or Install)**:
   - Perform required code modifications directly.
   - Run stack-native static analysis and linter (e.g. `flutter analyze`, `npm run lint`, `tsc --noEmit`, `ruff check`, `cargo clippy`, `golangci-lint`) to ensure zero errors.
   - Run stack-native tests (e.g. `flutter test`, `npm test`, `pytest`, `cargo test`, `go test`) to ensure zero regression.
   - **DO NOT build or install/deploy apps or run live servers to connected devices/production environments UNLESS explicitly instructed by the user.**
   - Deliver clear, concise reports with clickable links to modified files.

4. **Universal Autonomous UI Quality Iteration Loop (AQIL)**:
   - Universally applicable across any front-end/UI stack (Flutter, Web/React/Next.js/Vue, Android Jetpack Compose, iOS SwiftUI).
   - Ensure all responsive components and screens render with zero layout overflow or broken flex across 5 standard viewports (320px compact mobile, 393px standard mobile, 412px large mobile, 800px tablet portrait, 1280px tablet/desktop landscape).
   - Test dynamic accessibility font scaling (1.0x, 1.3x, and 1.5x) to guarantee zero text truncation, line collision, or unsafe clipping.
   - Verify smooth screen navigation and frame timing without dropped transition frames.
   - Enforce defensive layout standards: join multi-part subtitle metadata with single text delimiters (`' • '`), use proportional clamped constraints (`clamp(min, max)`), ensure all single-line texts have ellipsis truncation safeguards, and maintain minimum accessible touch targets (≥ 44×44 pt/dp).

5. **Universal Autonomous Feature Iteration Loop (AFIL / Auto-Loop)**:
   - Universally applicable across any software project (Mobile, Web, Backend, Cloud, Fullstack, CLI).
   - When the user specifies a loop count or an end goal (e.g. `"loop 4 times"`, `"auto-loop 3"`, `"iterate N times"`, `"goal: X in N loops"`, `"run afil, aqil, and achc simultaneously"`), automatically activate the universal tripartite engine.
   - **Simultaneous Operation**: In every cycle, **AFIL** (feature construction), **AQIL** (UI anti-overflow & multi-viewport quality), and **ACHS/ACHC** (code hygiene, deduplication & security) operate simultaneously in locked synchrony:
     1. **Phase 1 (Audit)**: Discover the highest-priority architectural or feature gap against the target goal or industry domain benchmark.
     2. **Phase 2 (Blueprint)**: Formulate the cycle's scope, data models, contracts, and APIs.
     3. **Phase 3 (Implement)**: Autonomously implement services, domain logic, and defensive responsive UI adhering to AQIL standards.
     4. **Phase 4 (Verify with AQIL)**: Run unit tests, AQIL multi-viewport UI checks ($320\text{px}$–$1440\text{px}$, font scale $1.5\times$), and stack-native static analysis.
     5. **Phase 5 (Heal)**: Automatically remediate any bugs, failed tests, or layout overflows.
     6. **Phase 6 (ACHS/ACHC Clean & Secure)**: Execute dead code pruning, feature deduplication (DRY), and security posture checks.
     7. **Phase 7 (Handoff)**: Checkpoint results and immediately start the next cycle until all $N$ loops are completed.

6. **Universal Autonomous Code Hygiene, Deduplication & Security Standard (ACHS)**:
   - Universally enforced across all projects and feature loops:
     - **Dead Code Elimination**: Prune unused imports, dead variables, obsolete methods, orphaned files, and run stack-native linter fixes (e.g. `dart fix --apply`, `npm run lint -- --fix`, `ruff check --fix`, `cargo fix`).
     - **Feature Deduplication (DRY)**: Actively detect redundant logic (> 2 occurrences of parsing, formatting, color conversion, or repetitive helpers) and consolidate them into shared project domain/core utilities.
     - **Enterprise Security & Safety**:
       - Ensure zero hardcoded API keys, secrets, or private tokens in source code.
       - Enforce least-privilege role boundaries (admin, manager, user) both client-side and in backend security rules/authorization guards.
       - Cryptographically protect sensitive credentials (e.g. hash with SHA-256, bcrypt, or Argon2 before storage).
       - Ensure all deserializers and API parsers implement defensive null-safe fallback defaults to guarantee zero runtime crashes.
