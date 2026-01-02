# Firebase Cloud Functions - MoMo Payment Webhook

## Cấu trúc

```
functions/
├── index.js        # Cloud Functions code
├── package.json    # Dependencies
└── README.md       # Hướng dẫn này
```

## Các Functions

### 1. `momoWebhook`
- **URL**: `https://asia-southeast1-quanlynhahang-d858b.cloudfunctions.net/momoWebhook`
- **Method**: POST
- **Chức năng**: Nhận IPN callback từ MoMo khi thanh toán thành công
- **Flow**:
  1. MoMo gọi webhook khi khách hàng thanh toán
  2. Function xác thực và parse thông tin đơn hàng
  3. Cập nhật `pending_payments/{restaurantId}/{orderId}` với `status: "completed"`
  4. App Flutter lắng nghe thay đổi và tự động cập nhật UI

### 2. `confirmPayment`
- **URL**: `https://asia-southeast1-quanlynhahang-d858b.cloudfunctions.net/confirmPayment`
- **Method**: POST
- **Body**: `{ "restaurantId": "...", "orderId": "...", "transactionId": "..." }`
- **Chức năng**: API để app gọi xác nhận thanh toán thủ công

### 3. `cleanupPendingPayments`
- **Chức năng**: Tự động dọn dẹp pending payments cũ (hơn 24h)
- **Schedule**: Mỗi 6 tiếng

---

## Hướng dẫn Deploy

### Bước 1: Cài đặt dependencies

```bash
cd functions
npm install
```

### Bước 2: Cấu hình MoMo

Mở file `index.js` và cập nhật thông tin MoMo thật:

```javascript
const MOMO_CONFIG = {
  partnerCode: "YOUR_PARTNER_CODE",
  accessKey: "YOUR_ACCESS_KEY",
  secretKey: "YOUR_SECRET_KEY",
  phoneNumber: "YOUR_MOMO_PHONE",
};
```

### Bước 3: Deploy

```bash
# Deploy tất cả functions
firebase deploy --only functions

# Hoặc deploy từng function
firebase deploy --only functions:momoWebhook
firebase deploy --only functions:confirmPayment
```

### Bước 4: Cấu hình MoMo Business

1. Đăng nhập vào [MoMo Business](https://business.momo.vn)
2. Vào **Cài đặt** → **Webhook/IPN**
3. Thêm URL webhook:
   ```
   https://asia-southeast1-quanlynhahang-d858b.cloudfunctions.net/momoWebhook
   ```
4. Lưu cấu hình

---

## Test với Webhook.site (Không có MoMo Business)

Nếu chưa có tài khoản MoMo Business, bạn có thể test bằng cách:

### Cách 1: Dùng Firebase Console

1. Mở Firebase Console → Realtime Database
2. Navigate đến: `pending_payments/{restaurantId}/{orderId}`
3. Thay đổi `status` từ `"pending"` thành `"completed"`
4. App sẽ tự động nhận được cập nhật

### Cách 2: Gọi API confirmPayment

```bash
curl -X POST \
  https://asia-southeast1-quanlynhahang-d858b.cloudfunctions.net/confirmPayment \
  -H "Content-Type: application/json" \
  -d '{
    "restaurantId": "YOUR_RESTAURANT_ID",
    "orderId": "YOUR_ORDER_ID",
    "transactionId": "TEST_123"
  }'
```

---

## Xem Logs

```bash
# Xem logs realtime
firebase functions:log

# Xem logs trong Firebase Console
# https://console.firebase.google.com/project/quanlynhahang-d858b/functions/logs
```

---

## Troubleshooting

### Lỗi "Permission Denied"

Kiểm tra Firebase Database Rules đã có rule cho `pending_payments`:

```json
"pending_payments": {
  ".read": "auth != null",
  ".write": "auth != null"
}
```

### Function không được gọi

1. Kiểm tra URL webhook đã đúng chưa
2. Kiểm tra MoMo đã cấu hình IPN URL chưa
3. Xem logs để debug

### QR code không hoạt động

Đảm bảo format QR code đúng:
```
2|99|SĐT|TÊN|NỘI DUNG|0|0|SỐ TIỀN
```

Ví dụ:
```
2|99|0987654321|NHA HANG ABC|TT Ban 5 DH abc12345|0|0|150000
```
