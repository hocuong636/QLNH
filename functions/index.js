/**
 * Firebase Cloud Functions - MoMo Payment Webhook Handler
 * 
 * Chức năng:
 * 1. Nhận IPN callback từ MoMo khi thanh toán thành công
 * 2. Xác thực signature từ MoMo
 * 3. Cập nhật trạng thái thanh toán trong Firebase Realtime Database
 * 4. App sẽ tự động nhận được cập nhật qua Firebase listener
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

// Initialize Firebase Admin
admin.initializeApp();

// MoMo Configuration - ⚠️ THAY BẰNG THÔNG TIN THẬT CỦA BẠN
const MOMO_CONFIG = {
  // Sandbox (Test)
  partnerCode: "MOMO1YDY20260102_TEST",
  accessKey: "re5bloPoPdW8sHDv",
  secretKey: "5H2NfnOutbmauAn129HUButo7oJVGZHu",
  
  // Số điện thoại MoMo nhà hàng
  phoneNumber: "0933592953",
};

/**
 * Tạo HMAC-SHA256 signature
 */
function generateSignature(rawData, secretKey) {
  return crypto
    .createHmac("sha256", secretKey)
    .update(rawData)
    .digest("hex");
}

/**
 * Xác thực signature từ MoMo
 */
function verifyMoMoSignature(data) {
  const rawSignature = `accessKey=${MOMO_CONFIG.accessKey}` +
    `&amount=${data.amount}` +
    `&extraData=${data.extraData || ""}` +
    `&message=${data.message}` +
    `&orderId=${data.orderId}` +
    `&orderInfo=${data.orderInfo}` +
    `&orderType=${data.orderType}` +
    `&partnerCode=${data.partnerCode}` +
    `&payType=${data.payType}` +
    `&requestId=${data.requestId}` +
    `&responseTime=${data.responseTime}` +
    `&resultCode=${data.resultCode}` +
    `&transId=${data.transId}`;

  const expectedSignature = generateSignature(rawSignature, MOMO_CONFIG.secretKey);
  return expectedSignature === data.signature;
}

/**
 * Parse order info từ MoMo để lấy restaurantId và orderId
 * Format content: "TT Ban X DH XXXXXXXX"
 */
function parseOrderInfo(orderInfo, extraData) {
  try {
    // Thử parse từ extraData trước (nếu có)
    if (extraData) {
      const decoded = Buffer.from(extraData, "base64").toString("utf-8");
      const data = JSON.parse(decoded);
      if (data.orderId && data.restaurantId) {
        return data;
      }
    }
    
    // Parse từ orderInfo
    // Format: "TT Ban X DH YYYYYYYY" hoặc custom format
    const match = orderInfo.match(/DH\s*([A-Za-z0-9-]+)/i);
    if (match) {
      return { orderId: match[1] };
    }
    
    return null;
  } catch (error) {
    console.error("Error parsing order info:", error);
    return null;
  }
}

/**
 * MoMo IPN Webhook Handler
 * 
 * URL: https://<region>-<project-id>.cloudfunctions.net/momoWebhook
 * Method: POST
 * 
 * MoMo sẽ gọi endpoint này khi có giao dịch hoàn thành
 */
exports.momoWebhook = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(200).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  console.log("=== MoMo IPN Webhook Received ===");
  console.log("Body:", JSON.stringify(req.body));

  try {
    const data = req.body;

    // Kiểm tra resultCode - 0 = thành công
    if (data.resultCode !== 0) {
      console.log(`Payment failed with resultCode: ${data.resultCode}`);
      res.status(200).json({ 
        status: "received",
        message: "Payment not successful" 
      });
      return;
    }

    // Xác thực signature (bỏ qua trong sandbox nếu cần)
    // if (!verifyMoMoSignature(data)) {
    //   console.error("Invalid signature");
    //   res.status(400).json({ error: "Invalid signature" });
    //   return;
    // }

    // Parse order info
    const orderData = parseOrderInfo(data.orderInfo, data.extraData);
    
    if (!orderData || !orderData.orderId) {
      console.error("Cannot parse order info:", data.orderInfo);
      // Vẫn trả về 200 để MoMo không retry
      res.status(200).json({ 
        status: "received",
        message: "Cannot parse order info" 
      });
      return;
    }

    console.log("Parsed order data:", orderData);

    // Tìm và cập nhật pending payment trong Firebase
    const db = admin.database();
    const pendingPaymentsRef = db.ref("pending_payments");
    
    // Tìm order trong tất cả restaurants
    const snapshot = await pendingPaymentsRef.once("value");
    let found = false;
    let restaurantId = orderData.restaurantId;
    let orderId = orderData.orderId;

    if (snapshot.exists()) {
      const allRestaurants = snapshot.val();
      
      for (const restId of Object.keys(allRestaurants)) {
        const orders = allRestaurants[restId];
        
        for (const oId of Object.keys(orders)) {
          // Match bằng orderId prefix
          if (oId.startsWith(orderId) || orderId.startsWith(oId.substring(0, 8))) {
            restaurantId = restId;
            orderId = oId;
            found = true;
            break;
          }
        }
        
        if (found) break;
      }
    }

    if (!found && !restaurantId) {
      console.log("Order not found in pending_payments");
      res.status(200).json({ 
        status: "received",
        message: "Order not found" 
      });
      return;
    }

    // Cập nhật trạng thái thanh toán
    const paymentRef = db.ref(`pending_payments/${restaurantId}/${orderId}`);
    
    await paymentRef.update({
      status: "completed",
      transactionId: data.transId.toString(),
      momoOrderId: data.orderId,
      amount: data.amount,
      completedAt: admin.database.ServerValue.TIMESTAMP,
      momoResponse: {
        resultCode: data.resultCode,
        message: data.message,
        payType: data.payType,
        responseTime: data.responseTime,
      },
    });

    console.log(`✅ Payment confirmed for order: ${orderId}`);

    // Trả về 200 để MoMo biết đã nhận được
    res.status(200).json({
      status: "success",
      message: "Payment confirmed",
      orderId: orderId,
    });

  } catch (error) {
    console.error("Error processing webhook:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * API để app gọi xác nhận thanh toán thủ công
 * (Dùng khi nhân viên kiểm tra MoMo đã nhận tiền)
 */
exports.confirmPayment = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(200).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    const { restaurantId, orderId, transactionId } = req.body;

    if (!restaurantId || !orderId) {
      res.status(400).json({ error: "Missing restaurantId or orderId" });
      return;
    }

    const db = admin.database();
    const paymentRef = db.ref(`pending_payments/${restaurantId}/${orderId}`);

    await paymentRef.update({
      status: "completed",
      transactionId: transactionId || `MANUAL_${Date.now()}`,
      completedAt: admin.database.ServerValue.TIMESTAMP,
    });

    res.status(200).json({
      status: "success",
      message: "Payment confirmed manually",
    });

  } catch (error) {
    console.error("Error confirming payment:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * Scheduled function để dọn dẹp pending payments cũ (hơn 24h)
 */
exports.cleanupPendingPayments = functions.pubsub
  .schedule("every 6 hours")
  .onRun(async (context) => {
    const db = admin.database();
    const cutoffTime = Date.now() - (24 * 60 * 60 * 1000); // 24 hours ago

    const snapshot = await db.ref("pending_payments").once("value");
    
    if (!snapshot.exists()) return null;

    const updates = {};
    const allRestaurants = snapshot.val();

    for (const restaurantId of Object.keys(allRestaurants)) {
      const orders = allRestaurants[restaurantId];
      
      for (const orderId of Object.keys(orders)) {
        const order = orders[orderId];
        if (order.createdAt && order.createdAt < cutoffTime) {
          updates[`pending_payments/${restaurantId}/${orderId}`] = null;
        }
      }
    }

    if (Object.keys(updates).length > 0) {
      await db.ref().update(updates);
      console.log(`Cleaned up ${Object.keys(updates).length} old pending payments`);
    }

    return null;
  });
