# DSGames v20 PRO Admin

Bản nâng cấp Admin Control Center cho DSGames.

## Nâng cấp chính
- Dashboard tổng quan License/Games.
- Thống kê tổng License, đang hoạt động, Online, sắp/hết hạn.
- Biểu đồ tình trạng License dạng progress.
- System Health và build version.
- Tìm kiếm License/Game.
- Bộ lọc License: Online, Offline, hoạt động, sắp hết hạn, hết hạn, chưa kích hoạt.
- Hiện/Copy License Key.
- Sửa/Xóa License.
- Gia hạn bằng ngày giờ cụ thể và nút nhanh.
- Gỡ liên kết thiết bị khỏi License.
- Hiển thị thiết bị, iOS, Online, Last Seen và hạn sử dụng.
- Quản lý Game.
- Toast thông báo thao tác.
- Cache-control cho Admin để tránh giữ giao diện Worker cũ.
- Giữ nguyên D1 database `dsgames` và binding `DB` hiện tại.

## Deploy Worker
```powershell
cd worker
npx.cmd wrangler deploy
```

Sau khi deploy mở:
`https://dsgames-catalog.hieuvlog2001.workers.dev/admin`

Nếu trình duyệt còn giao diện cũ: Ctrl + F5 hoặc mở cửa sổ ẩn danh.
