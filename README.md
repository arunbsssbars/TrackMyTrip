# TrackMyTrip

[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.x-teal.svg)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Riverpod%20%2B%20Offline--First-indigo.svg)](https://riverpod.dev)
[![Tests Passing](https://img.shields.io/badge/Tests-Passing-brightgreen.svg)](https://github.com/arunbsssbars/TrackMyTrip)
[![Release](https://img.shields.io/badge/Release-v2.3--overhaul-orange.svg)](https://github.com/arunbsssbars/TrackMyTrip/releases)

**TrackMyTrip** is an enterprise-grade, offline-first mobile application designed for solo travelers, families, and expedition convoys. It unifies high-precision GPS telemetry, multi-party mathematical expense splitting, real-time companion radar, and anti-resurrection distributed data integrity across SQLite and Cloud Firestore.

---

## Table of Contents
- [1. Executive Architectural Overview](#1-executive-architectural-overview)
- [2. Anti-Resurrection Tombstone System](#2-anti-resurrection-tombstone-system)
- [3. Core Financial Ledger & Split Engine](#3-core-financial-ledger--split-engine)
- [4. Component Hierarchy & File Structure](#4-component-hierarchy--file-structure)
- [5. Database Schema & Storage Architecture](#5-database-schema--storage-architecture)
- [6. Navigation & Global UI System](#6-navigation--global-ui-system)
- [7. Testing & Verification Suite](#7-testing--verification-suite)
- [8. Build & Deployment Commands](#8-build--deployment-commands)

---

## 1. Executive Architectural Overview

TrackMyTrip follows a decoupled, layered Clean Architecture powered by **Flutter Riverpod**:

```
┌─────────────────────────────────────────────────────────────┐
│                 Presentation & UI Layer                     │
│  CurrentTripTab • TripDetailScreen • UniversalBottomBar      │
│  CurrentTripHeroCard • TripMenuButton • SosBadgeIcon        │
└──────────────────────────────┬──────────────────────────────┘
                               │ State Notifiers & Providers
┌──────────────────────────────▼──────────────────────────────┐
│                  Business & Domain Layer                    │
│  TripProvider • ExpenseProvider • SettlementProvider        │
│  LedgerIntegrityService • DebtSimplifier • LocationService  │
└──────────────────────────────┬──────────────────────────────┘
                               │ Inbound & Outbound Sync Guards
┌──────────────────────────────▼──────────────────────────────┐
│                    Data & Storage Layer                     │
│  AppDatabase (SQLite) • LocalStorageService • SharedPreferences
│  FirestoreSyncService (Cloud Firestore) • RealtimeSyncService
│  TombstoneService (Dual-Layer Memory + Disk Cache)          │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Anti-Resurrection Tombstone System

### The Distributed Resurrection Challenge
In hybrid offline-first architectures (SQLite + Cloud Firestore), deleted entities frequently "resurrect":
1. When a trip is deleted locally, offline caches or pending Firestore snapshots still hold cached documents.
2. Upon cold start, account re-login, or network reconnection, Firestore delivers the cached document.
3. Without tombstones, the app interprets this as an active trip, re-inserts it into SQLite, and triggers mutations that re-push it to the cloud.

### Enterprise Solution: Dual-Layer Tombstones
TrackMyTrip enforces **Anti-Resurrection Invariants** via [`TombstoneService`](file:///d:/Program/Antigravity/TripTrackerApp/lib/core/services/tombstone_service.dart):

```
                   Trip Deletion Triggered
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
    [1. Local Dual-Layer]          [2. Remote Cloud Purge]
    - In-Memory Set                - Write 'deleted_trips_tombstones/{id}'
    - SharedPreferences Cache      - Set 'trips/{id}.status = deleted'
    - SQLite 'tombstoned_trips'    - Purge 8 subcollections
                                   - Delete 'trip_rooms/{id}'
                                   - Delete 'trips/{id}' document
              │                               │
              └───────────────┬───────────────┘
                              ▼
           [3. Active Inbound & Outbound Sync Guards]
   - All inbound snapshot listeners immediately drop tombstoned IDs
   - All outbound push mutations abort if ID is in TombstoneService
   - SQLite executes atomic cascade transaction on all related rows
```

#### Invariants Enforced:
1. **$O(1)$ Synchronous Interception**: Inbound listener streams query `TombstoneService.isTombstoned(tripId)` prior to deserialization or SQLite insertion.
2. **Cold-Start Resilience**: `SharedPreferences` cache initializes before database connection or network streams boot up.
3. **Atomic Cascade Deletion**: `AppDatabase.deleteTrip(tripId)` executes within an atomic SQLite transaction clearing `trips`, `stoppages`, `expenses`, `memories`, `settlements`, `audit_logs`, `proximity_alerts`, and `trip_invitations`.

---

## 3. Core Financial Ledger & Split Engine

Financial software requires absolute mathematical precision. TrackMyTrip guarantees zero floating-point accumulation drift:

### Mathematical Invariants
1. **Conservation of Money**:
   $$\sum_{i=1}^{N} \text{SplitAmount}_i = \text{TotalBillAmount}$$
   *Single-Cent Remainder Distribution*: When dividing amounts with non-terminating decimals (e.g. $\$100.00 / 3 = \$33.333...$), base shares are truncated to $\$33.33$, and the $\$0.01$ remainder is allocated to the payer or first member ($\$33.34 + \$33.33 + \$33.33 = \$100.00$).

2. **Zero-Sum Group Ledger Balance**:
   Across all members of any group trip:
   $$\sum_{m=1}^{M} \text{NetBalance}_m = 0.00 \pm 0.00$$
   - $\text{NetBalance}_m > 0 \implies \text{Creditor (owed money by group)}$
   - $\text{NetBalance}_m < 0 \implies \text{Debtor (owes money to group)}$
   - $\text{NetBalance}_m = 0 \implies \text{Settled}$

3. **Optimal Debt Minimization**:
   Implemented in [`DebtSimplifier`](file:///d:/Program/Antigravity/TripTrackerApp/lib/core/services/debt_simplifier.dart) using a greedy bipartite cash-flow algorithm to reduce $N$-party debts into the minimum possible transactions.

4. **Self-Healing Validator**:
   [`LedgerIntegrityService`](file:///d:/Program/Antigravity/TripTrackerApp/lib/core/services/ledger_integrity_service.dart) provides continuous runtime auditing to ensure all splits strictly satisfy conservation and report zero drift.

---

## 4. Component Hierarchy & File Structure

```
lib/
├── core/
│   ├── database/
│   │   └── app_database.dart                 # SQLite schema, transactions, migrations
│   ├── services/
│   │   ├── tombstone_service.dart            # Anti-resurrection dual-layer store
│   │   ├── ledger_integrity_service.dart     # Integer-cent financial ledger validator
│   │   ├── firestore_sync_service.dart       # Cloud Firestore real-time sync & cloud purge
│   │   ├── proximity_alert_service.dart      # Convoy separation & proximity engine
│   │   ├── location_service.dart             # GPS geolocation & reverse geocoding
│   │   └── pdf_export_service.dart           # Executive PDF trip report generator
│   └── theme/
│       └── app_theme.dart                    # Design system tokens, dark/light modes
├── models/
│   ├── trip.dart                             # Trip metadata, members, budget
│   ├── stoppage.dart                         # Itinerary waypoints & category models
│   ├── expense.dart                          # Expense, receipt photo, location tag
│   └── expense_split.dart                    # Split allocation shares & percentages
├── screens/
│   ├── common/
│   │   ├── trip_menu_button.dart             # Unified 3-dots actions (Edit, Share, PDF, Delete)
│   │   ├── universal_bottom_bar.dart         # Persistent docked navigation bar
│   │   └── sos_badge_icon.dart               # Calm, eye-friendly emergency safety badge
│   ├── expense/
│   │   └── add_expense_screen.dart           # Bill logging, GPS proximity match, receipt zoom
│   ├── stats/
│   │   └── trip_analytics_screen.dart        # Expenditure graphs & category analytics
│   ├── trip/
│   │   └── current_trip_tab.dart             # Active journey cockpit, launchpad, telemetry
│   └── trip_detail/
│       ├── trip_detail_screen.dart           # 6-tab journey workspace
│       └── tabs/                             # Timeline, Route, Members, Bills, Settle, Memories
└── widgets/
    └── current_trip_hero_card.dart           # Extracted executive cockpit hero card widget
```

---

## 5. Database Schema & Storage Architecture

TrackMyTrip utilizes **per-user database partitioning** (`trip_tracker_{uid}.db`) ensuring strict multi-tenant isolation on the physical device:

| Table | Primary Key | Key Foreign Keys / Indexed Columns | Purpose |
| :--- | :--- | :--- | :--- |
| `trips` | `id TEXT` | `createdAt`, `status` | Journey metadata, budget, currency |
| `stoppages` | `id TEXT` | `tripId`, `arrivalDate` | Itinerary stops, location coordinates |
| `expenses` | `id TEXT` | `tripId`, `stoppageId`, `date` | Financial records, receipt photos, GPS |
| `expense_splits` | `id TEXT` | `expenseId`, `tripId`, `memberId` | Individual shares and split weights |
| `settlements` | `id TEXT` | `tripId`, `payerId`, `receiverId` | Cleared peer-to-peer repayments |
| `memories` | `id TEXT` | `tripId`, `stoppageId` | Photos and journey milestones |
| `tombstoned_trips` | `tripId TEXT` | `deletedAt INTEGER` | Permanent tombstone registry |
| `audit_logs` | `id TEXT` | `tripId`, `timestamp` | Immutable audit trail for all changes |
| `proximity_alerts` | `id TEXT` | `tripId`, `timestamp` | Fleet convoy safety alerts |

---

## 6. Navigation & Global UI System

TrackMyTrip features a persistent dock navigation system:

- **Journeys Dashboard (Tab 0)**: `Icons.dashboard_rounded` / `Icons.dashboard_outlined`
- **Active Journey (Tab 1)**: `Icons.explore_rounded` / `Icons.explore_outlined`
- **Activity Hub (Tab 2)**: `Icons.bolt_rounded` / `Icons.bolt_outlined` with unread badge counter
- **Memories Feed (Tab 3)**: `Icons.photo_library_rounded` / `Icons.photo_library_outlined`
- **Profile (Tab 4)**: `Icons.person_rounded` / `Icons.person_outline_rounded`

The docked [`UniversalBottomBar`](file:///d:/Program/Antigravity/TripTrackerApp/lib/screens/common/universal_bottom_bar.dart) is mounted across both primary tabs and pushed screens (`TripDetailScreen`, `TripAnalyticsScreen`), allowing effortless 1-tap wayfinding back to top-level destinations without deep back-stack traversal.

---

## 7. Testing & Verification Suite

The repository contains **108 automated tests** passing at 100%:

```bash
# Execute the entire automated test suite
flutter test

# Run the dedicated CurrentTripHeroCard component test suite
flutter test test/current_trip_hero_card_test.dart

# Run anti-resurrection and financial integrity tests
flutter test test/tombstone_and_financial_integrity_test.dart

# Run SQLite cascade and storage tests
flutter test test/sqlite_storage_test.dart

# Run static code analysis (Enforces zero errors/warnings)
flutter analyze
```

---

## 8. Build & Deployment Commands

```bash
# Run on connected mobile device or emulator
flutter run -d <device-id>

# Build production Android APK (Universal)
flutter build apk --release

# Build split-per-ABI release APKs (Optimized size)
flutter build apk --release --split-per-abi

# Build Android App Bundle for Google Play Store
flutter build appbundle --release
```

---

## Release Tag
Current production baseline: **`v2.3-overhaul`**#   T r a c k M y T r i p  
 #   T r a c k M y T r i p  
 