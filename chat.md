# Chat

## Arah Produk
Menu chat diposisikan sebagai pusat komunikasi operasional warga, admin RT, dan admin RW. Fokusnya bukan chat sosial bebas, tetapi komunikasi layanan, koordinasi grup wilayah, dan pengumuman resmi.

## Scope MVP yang Diimplementasikan
- Inbox layanan per warga
- Grup RT sesuai scope wilayah
- Forum RW untuk admin RT, admin RW, dan admin RW Pro
- Pengumuman scoped per RT/RW
- Pengiriman pesan teks
- Bootstrap percakapan otomatis dari area dan role user

## Collection PocketBase
### conversations
- `key`: kunci unik percakapan sistem
- `type`: `private`, `group_rt`, `group_rw`
- `name`
- `owner`: pemilik inbox layanan warga
- `created_by`
- `rt`, `rw`
- `desa_code`, `kecamatan_code`, `kabupaten_code`, `provinsi_code`
- `desa_kelurahan`, `kecamatan`, `kabupaten_kota`, `provinsi`
- `is_readonly`
- `last_message`
- `last_message_at`
- `created`, `updated`

### conversation_members
Disiapkan untuk pengembangan tahap berikutnya seperti unread, mute, dan member state yang lebih kaya.

### messages
- `conversation`
- `sender`
- `text`
- `attachment`
- `message_type`
- `created`, `updated`

### message_reads
Disiapkan untuk unread tracking tahap berikutnya.

### announcements
- `author`
- `title`
- `content`
- `target_type`: `rt` atau `rw`
- `rt`, `rw`
- field area code dan area name
- `is_published`
- `created`, `updated`

## Aturan Role
### warga
- melihat inbox layanan miliknya sendiri
- melihat grup RT miliknya
- melihat pengumuman RT/RW yang sesuai area
- tidak melihat forum RW admin

### admin_rt
- melihat semua inbox layanan warga di RT yang sama
- melihat grup RT sendiri
- melihat forum RW
- membuat pengumuman target RT

### admin_rw / admin_rw_pro
- melihat semua inbox layanan warga di RW yang sama
- melihat semua grup RT dalam RW yang sama
- melihat forum RW
- membuat pengumuman target RT atau RW

### sysadmin
- akses penuh untuk audit dan supervisi

## Custom API Route
- `GET /api/rukunwarga/chat/bootstrap`
- `GET /api/rukunwarga/chat/conversations/{conversationId}/messages`
- `POST /api/rukunwarga/chat/conversations/{conversationId}/messages`
- `GET /api/rukunwarga/chat/announcements`
- `POST /api/rukunwarga/chat/announcements`

## Perilaku Bootstrap
Saat menu chat dibuka:
- warga otomatis mendapatkan inbox layanan dan grup RT sesuai area
- admin RT otomatis mendapatkan grup RT, forum RW, dan inbox layanan warga di RT-nya
- admin RW dan admin RW Pro otomatis mendapatkan forum RW, grup RT dalam RW, dan inbox layanan warga di RW-nya

## Catatan Pengembangan Lanjutan
Belum diaktifkan di tahap ini:
- attachment chat di UI
- unread counter real-time
- mute, pin, archive
- thread layanan per surat/dokumen/iuran
- DM bebas antar-warga

## File Implementasi
- `pb_migrations/1773050001_created_chat_collections.js`
- `pb_hooks/chat.pb.js`
- `lib/core/services/chat_service.dart`
- `lib/shared/models/chat_model.dart`
- `lib/features/chat/screens/chat_list_screen.dart`
- `lib/features/chat/screens/chat_room_screen.dart`
- `lib/features/chat/screens/announcement_screen.dart`
