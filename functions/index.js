/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.finalizePausedSubscriptions = functions.pubsub
  .schedule('0 22 * * *') // 10 PM every day
  .timeZone('YOUR_TIMEZONE') // e.g., 'Asia/Kolkata'
  .onRun(async (context) => {
    const firestore = admin.firestore();
    const usersSnapshot = await firestore.collection('users').get();
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(0, 0, 0, 0); // Start of tomorrow
    const tomorrowEnd = new Date(tomorrow);
    tomorrowEnd.setHours(23, 59, 59, 999); // End of tomorrow

    const batch = firestore.batch();
    for (const userDoc of usersSnapshot.docs) {
      const data = userDoc.data();
      if (data.isPaused === true && data.subscriptionEndDate) {
        // Extend subscription end date by 1 day
        const currentEndDate = data.subscriptionEndDate.toDate();
        const newEndDate = new Date(currentEndDate);
        newEndDate.setDate(newEndDate.getDate() + 1);

        batch.update(userDoc.ref, {
          subscriptionEndDate: admin.firestore.Timestamp.fromDate(newEndDate),
        });

        // Pause tomorrow's orders
        const ordersSnapshot = await firestore
          .collection('orders')
          .where('userId', '==', userDoc.id)
          .where('status', '==', 'Pending Delivery')
          .where('date', '>=', admin.firestore.Timestamp.fromDate(tomorrow))
          .where('date', '<=', admin.firestore.Timestamp.fromDate(tomorrowEnd))
          .get();

        for (const orderDoc of ordersSnapshot.docs) {
          batch.update(orderDoc.ref, { status: 'Paused' });
        }
      } else if (data.isPaused === false) {
        // Resume tomorrow's orders if paused
        const ordersSnapshot = await firestore
          .collection('orders')
          .where('userId', '==', userDoc.id)
          .where('status', '==', 'Paused')
          .where('date', '>=', admin.firestore.Timestamp.fromDate(tomorrow))
          .where('date', '<=', admin.firestore.Timestamp.fromDate(tomorrowEnd))
          .get();

        for (const orderDoc of ordersSnapshot.docs) {
          batch.update(orderDoc.ref, { status: 'Pending Delivery' });
        }
      }
    }

    await batch.commit();
    console.log('Daily pause finalization completed');
    return null;
  });