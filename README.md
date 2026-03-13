# RukunWarga — Sistem Manajemen Rukun Warga

Aplikasi Flutter untuk manajemen administrasi RT/RW dengan fitur lengkap: data kependudukan, surat pengantar, iuran warga, keuangan, chat, dan laporan operasional.

---

## 🎯 Ringkasan Produk

| Aspek | Detail |
|-------|--------|
| **Target User** | Warga, Admin RT, Admin RW, Admin RW Pro, Sysadmin |
| **Platform** | Android, iOS, Web, Windows, macOS, Linux |
| **Backend** | PocketBase (self-hosted) |
| **State Management** | Riverpod |
| **Navigation** | GoRouter |
| **UI Framework** | Material 3, Custom Design System 2026 |

---

## 📂 Struktur Proyek

```
lib/
├── main.dart                    # Entry point
├── app/
│   ├── app.dart                 # RukunWargaApp widget
│   ├── router.dart              # GoRouter routes & navigation
│   ├── theme.dart               # Design tokens & tema aplikasi
│   └── providers/               # App-level providers
├── core/
│   ├── config/                  # Environment config
│   ├── constants/               # App constants, collection names, roles
│   ├── services/                # Business logic services
│   └── utils/                   # Helpers (formatters, error classifier, area access)
├── features/
│   ├── auth/                    # Login, register, auth state
│   ├── dashboard/               # Home dashboard
│   ├── warga/                   # Data warga (CRUD)
│   ├── kartu_keluarga/          # Data KK (CRUD + OCR)
│   ├── dokumen/                 # Upload & verifikasi dokumen
│   ├── surat/                   # Pengajuan & approval surat pengantar
│   ├── iuran/                   # Tagihan iuran, pembayaran, verifikasi
│   ├── finance/                 # Keuangan (kas, transaksi, approval)
│   ├── laporan/                 # Laporan operasional
│   ├── chat/                    # Chat inbox & grup wilayah
│   ├── notifikasi/              # Notifikasi sistem
│   ├── organization/            # Struktur organisasi RT/RW
│   └── settings/                # Pengaturan akun & subscription
└── shared/
    ├── models/                  # Data models
    └── widgets/                 # Reusable UI components
```

---

## 🔐 Role & Akses

| Role | System Role | Scope | Fitur Utama |
|------|-------------|-------|-------------|
| `warga` | `warga` | Data sendiri | Lihat data, ajukan surat, bayar iuran |
| `admin_rt` | `operator` | 1 RT | Kelola warga RT, approve surat level RT, verifikasi iuran |
| `admin_rw` | `operator` | 1 RW (semua RT) | Approve surat level RW, laporan RW, organisasi |
| `admin_rw_pro` | `operator` | RW + fitur premium | Finance publish, broadcast, export advanced |
| `sysadmin` | `sysadmin` | Semua | Full access, user management, subscription |

---

## 🧩 Alur Fitur Utama

### 1. Autentikasi
```
Login → Validasi Email/Password → Sync AuthState → Redirect ke Dashboard/Subscription
```

### 2. Data Kependudukan
```
KK (Kartu Keluarga) → Warga (Anggota KK) → Dokumen (KTP, KK, dll)
                  └── OCR Scan untuk ekstrak data otomatis
```

### 3. Surat Pengantar
```
Warga Submit Draft → Admin RT Review → (Approve/Revisi/Reject)
                                    └── Forward ke RW (jika approval_level=rw)
                                              └── Admin RW Approve → Completed
```

**Status Flow:**
`draft` → `submitted` → `approved_rt` / `need_revision` / `rejected`
                     → `forwarded_to_rw` → `approved_rw` → `completed`

### 4. Iuran Warga
```
Admin buat Periode + Jenis Iuran → Generate Tagihan per KK
Warga Bayar (upload bukti) → Admin Verifikasi → Lunas
                          → Posting ke Finance (opsional)
```

**Status Tagihan:**
`unpaid` → `submitted_verification` → `paid` / `rejected_payment`

### 5. Keuangan
```
Transaksi Manual / Auto dari Iuran → Approval (jika perlu) → Published ke Laporan
```

**Status Transaksi:**
`draft` → `pending_approval` → `approved` / `rejected` → `published`

### 6. Chat
```
Inbox (1-on-1) + Grup RT/RW → Realtime Messages
                           → Announcements (broadcast)
                           → Polling
```

### 7. Laporan Operasional
```
Dashboard Metrics → Filter by Range → Alert (tunggakan, revisi, pending)
                                   → Export PDF (iuran belum lunas)
```

---

## 🎨 Design System (2026)

### Color Palette
```dart
Primary: #3B82F6 (Blue)
Secondary: #8B5CF6 (Purple)
Accent: #10B981 (Green)
Success: #10B981
Warning: #F59E0B
Error: #EF4444
Info: #3B82F6
```

### Typography
- **Heading**: Semibold/Bold, 18-24px
- **Body**: Regular, 14-16px
- **Caption**: Medium, 11-13px

### Components
- `AppBadge` — Status/urgency indicators dengan pulse animation
- `StatusChip` — Semantic status badges
- `MenuItemCard` — Dashboard menu cards dengan micro-interactions
- `AppSurfaceCard` — Elevated surface cards
- `AppHeroPanel` — Hero section dengan icon dan chips
- `AppToast` — Micro-feedback notifications

---

## 🗄️ Collections (PocketBase)

### Core Collections
| Collection | Deskripsi |
|------------|-----------|
| `users` | Akun pengguna |
| `warga` | Data warga (profil lengkap) |
| `kartu_keluarga` | Data KK |
| `dokumen` | Upload dokumen warga |
| `surat` | Pengajuan surat pengantar |
| `surat_logs` | Audit trail surat |

### Iuran Collections
| Collection | Deskripsi |
|------------|-----------|
| `iuran_types` | Jenis iuran (kebersihan, keamanan, dll) |
| `iuran_periods` | Periode iuran (bulanan/tahunan) |
| `iuran_bills` | Tagihan per KK |
| `iuran_payments` | Bukti pembayaran |

### Finance Collections
| Collection | Deskripsi |
|------------|-----------|
| `finance_accounts` | Akun kas per unit |
| `finance_transactions` | Transaksi keuangan |
| `finance_approvals` | Approval transaksi |

### Organization Collections
| Collection | Deskripsi |
|------------|-----------|
| `workspaces` | Workspace (RT/RW) |
| `workspace_members` | Anggota workspace |
| `org_units` | Unit organisasi |
| `org_memberships` | Jabatan di unit |

### Chat Collections
| Collection | Deskripsi |
|------------|-----------|
| `conversations` | Percakapan |
| `conversation_members` | Anggota chat |
| `messages` | Pesan |
| `announcements` | Pengumuman |

---

## ⚙️ Setup Development

### Prerequisites
- Flutter SDK 3.24+
- Dart 3.5+
- PocketBase 0.36+

### Installation
```bash
# Clone repository
git clone <repo-url>
cd rukunwarga19-1

# Install dependencies
flutter pub get

# Run PocketBase (terminal terpisah)
cd pocketbase_0.36.2_windows_amd64
./pocketbase serve

# Run Flutter app
flutter run -d chrome
```

### Environment Variables
Buat file `.env` atau gunakan `--dart-define`:
```
POCKETBASE_URL=http://127.0.0.1:8090
```

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Analyze code
flutter analyze
```

### Test Coverage (Current)
- ✅ KK OCR Service (parsing, inference)
- ⚠️ Widget tests (placeholder)
- ❌ Integration tests (belum ada)
- ❌ E2E tests (belum ada)

---

## 📋 Checklist Status Fitur

### Core Features
- [x] Authentication (login, register, logout)
- [x] Dashboard dengan menu grouped
- [x] Data Warga (CRUD)
- [x] Kartu Keluarga (CRUD + OCR)
- [x] Dokumen Upload & Verifikasi
- [x] Surat Pengantar (full workflow)
- [x] Iuran Warga (tagihan, bayar, verifikasi)
- [x] Keuangan (transaksi, approval, publish)
- [x] Chat (inbox, grup, announcements)
- [x] Laporan Operasional
- [x] Settings & Subscription
- [x] Organisasi RT/RW

### UI/UX 2026
- [x] Design tokens (color, typography)
- [x] AppBadge & StatusChip
- [x] MenuItemCard dengan micro-interactions
- [x] Dashboard updated
- [x] Surat screen updated
- [x] Dokumen screen updated
- [x] Iuran screen updated
- [ ] Finance screen (partial)
- [ ] Chat screen (partial)
- [ ] Settings screen (partial)
- [ ] All other screens (pending)

### Technical Debt
- [ ] Logging system (`app_logs` collection) — belum diimplementasi
- [ ] Comprehensive unit tests
- [ ] Integration tests
- [ ] Error boundary global
- [ ] Offline support / caching
- [ ] Push notifications (Firebase)

---

## 🚀 Deployment

### Web (Firebase Hosting)
```bash
flutter build web --release
firebase deploy --only hosting
```

### Android (AAB)
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### Android (APK arm)
```bash
flutter clean
flutter pub get
flutter build apk --target-platform android-arm
```

---

## 📝 Konvensi Kode

### File Naming
- `snake_case` untuk file: `warga_list_screen.dart`
- `PascalCase` untuk class: `WargaListScreen`
- `camelCase` untuk variable/method: `fetchWargaList()`

### Folder Structure per Feature
```
features/
└── <feature>/
    ├── providers/       # Riverpod providers
    ├── screens/         # UI screens
    ├── widgets/         # Feature-specific widgets
    └── services/        # Feature-specific services (jika perlu)
```

### State Management
- Gunakan `FutureProvider.autoDispose` untuk data fetching
- Gunakan `StateNotifierProvider` untuk complex state
- Gunakan `Provider` untuk services singleton

---

## 🔄 Git Workflow

```bash
# Quick commit & push
git add .
git commit -m "<ringkasan perubahan>"
git push
```

Trigger commands (lihat RULES.md):
- `git` — auto commit & push
- `deploy` — build web + firebase deploy
- `aab` — build Android App Bundle
- `arm` — build APK arm
- `run` — clean + run chrome

---

## 📚 Dokumentasi Terkait

- `RULES.md` — Aturan untuk AI agent
- `pocketbase_0.36.2_windows_amd64/pb_migrations/` — Database migrations

---

## 🎯 Roadmap v2

### Phase 1: Polish
- [ ] Complete UI/UX migration ke Design System 2026
- [ ] Implement `app_logs` untuk audit trail
- [ ] Add loading skeletons
- [ ] Improve error messages

### Phase 2: Testing
- [ ] Unit tests untuk semua services
- [ ] Widget tests untuk critical screens
- [ ] Integration tests untuk main flows

### Phase 3: Features
- [ ] Push notifications
- [ ] Offline mode
- [ ] Export data (PDF, Excel)
- [ ] Multi-language support

### Phase 4: Scale
- [ ] Performance optimization
- [ ] Analytics & monitoring
- [ ] CI/CD pipeline

---

## 👥 Tim

| Role | Tanggung Jawab |
|------|----------------|
| Product Owner | Definisi fitur, prioritas, acceptance criteria |
| Developer | Implementasi, testing, deployment |
| AI Agent | Code assistance, review, automation |

---

**Last Updated:** March 13, 2026
