# DSGames Online Catalog + License Key

Worker này quản lý danh mục game và License Key. Mỗi key có Hạn sử dụng (HSD) riêng.

## 1. Database hiện tại

Nếu bạn đang dùng database `dsgames` của bản trước, **không tạo database mới**. Chỉ chạy schema để tạo thêm bảng `licenses`: 

```powershell
npx wrangler d1 execute dsgames --remote --file=./schema.sql
```

## 2. Admin token

Nếu chưa có:

```powershell
npx wrangler secret put ADMIN_TOKEN
```

## 3. Deploy

```powershell
npx wrangler deploy
```

Admin:
`https://dsgames-catalog.hieuvlog2001.workers.dev/admin`

## 4. Quản lý License Key

Trong Admin có mục **License Key**:
- Tạo key tự động ngay trên trang quản lý (tự sinh Key ID + License Key) hoặc nhập key thủ công. Có nút **Tạo & lưu key tự động** để sinh và lưu trực tiếp vào D1.
- Đặt Key ID, ví dụ `customer-001`.
- Đặt tên khách hàng / ghi chú.
- Đặt HSD: +1 ngày, +7 ngày, +30 ngày, +1 năm hoặc không giới hạn.
- Bật/tắt key.
- Sửa HSD hoặc thu hồi key.
- Xóa key.

Key được lưu dưới dạng SHA-256 hash trong D1; database không lưu plaintext key. Khi tạo key mới, Admin hiển thị key một lần để bạn copy gửi cho khách.

## 5. App iOS

App dùng:
- `POST /api/license/activate` để kích hoạt key.
- `POST /api/license/check` để kiểm tra lại key khi mở app/quay lại app.
- `GET /api/games` để lấy danh sách game.

App lưu key đã kích hoạt trên máy và tự kiểm tra lại định kỳ. Khi key bị hết hạn hoặc bị tắt trên Admin, app sẽ không cho mở game và hiển thị trạng thái HSD tương ứng.

## 6. Luồng sử dụng

1. Admin vào `/admin`.
2. Nhập Admin token.
3. Tạo License Key.
4. Chọn HSD cho key.
5. Copy key gửi cho khách.
6. Khách mở DSGames và nhập key.
7. App xác thực với Worker.
8. Khi Admin gia hạn HSD, app tự nhận HSD mới ở lần kiểm tra tiếp theo.
9. Khi Admin tắt/xóa key hoặc key hết hạn, app mất quyền mở game.
