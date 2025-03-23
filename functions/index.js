const { onSchedule } = require('firebase-functions/v2/scheduler');
// Use console.log instead of logger for now, or fix the logger import below
const admin = require('firebase-admin');
admin.initializeApp();

function padLeft(num, size) {
  return String(num).padStart(size, '0');
}

exports.generateDailyOrders = onSchedule(
  {
    schedule: '0 0 * * *', // Every day at midnight
    timeZone: 'Asia/Tbilisi', // Georgia (country), UTC+4
  },
  async (context) => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrow = new Date(today);
    tomorrow.setDate(today.getDate() + 1);
    const tomorrowStr = `${tomorrow.getFullYear()}-${padLeft(tomorrow.getMonth() + 1, 2)}-${padLeft(tomorrow.getDate(), 2)}`;

    const usersSnapshot = await admin.firestore().collection('users')
      .where('activeSubscription', '==', true)
      .get();

    const batch = admin.firestore().batch();

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      const subscriptionId = userData.subscriptionId;
      const endDate = userData.endDate.toDate();
      const isPaused = userData.isPaused || false;

      if (tomorrow <= endDate && !isPaused) {
        const mealType = userData.mealType;
        const category = userData.category;

        if (mealType === 'Lunch' || mealType === 'Both') {
          const orderId = `${subscriptionId}-${tomorrowStr}-Lunch`;
          batch.set(admin.firestore().collection('users').doc(userId).collection('orders').doc(orderId), {
            orderId: orderId,
            subscriptionId: subscriptionId,
            userId: userId,
            date: admin.firestore.Timestamp.fromDate(tomorrow),
            mealType: 'Lunch',
            category: category,
            status: 'Pending Delivery',
            deliveryAssignedTo: null,
            createdAt: admin.firestore.Timestamp.now(),
          });
        }
        if (mealType === 'Dinner' || mealType === 'Both') {
          const orderId = `${subscriptionId}-${tomorrowStr}-Dinner`;
          batch.set(admin.firestore().collection('users').doc(userId).collection('orders').doc(orderId), {
            orderId: orderId,
            subscriptionId: subscriptionId,
            userId: userId,
            date: admin.firestore.Timestamp.fromDate(tomorrow),
            mealType: 'Dinner',
            category: category,
            status: 'Pending Delivery',
            deliveryAssignedTo: null,
            createdAt: admin.firestore.Timestamp.now(),
          });
        }
      }
    }

    await batch.commit();
    console.log(`Generated orders for ${tomorrowStr}`); // Replaced logger.log with console.log
    return null;
  }
);