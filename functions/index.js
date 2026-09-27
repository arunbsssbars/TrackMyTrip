const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onProximityAlertCreated = functions.firestore
  .document("trips/{tripId}/proximity_alerts/{alertId}")
  .onCreate(async (snap, context) => {
    const alertData = snap.data();
    const tripId = context.params.tripId;

    if (!alertData) return;

    // Fetch the parent trip document to retrieve the authorized companion member list
    const tripDoc = await admin.firestore().collection("trips").doc(tripId).get();
    if (!tripDoc.exists) {
      console.log(`Trip ${tripId} not found.`);
      return null;
    }

    const tripData = tripDoc.data() || {};
    const memberIds = new Set();
    
    if (tripData.creatorId) memberIds.add(tripData.creatorId);
    if (tripData.createdByMemberId) memberIds.add(tripData.createdByMemberId);
    if (Array.isArray(tripData.memberIds)) {
      tripData.memberIds.forEach((id) => memberIds.add(id));
    }
    if (Array.isArray(tripData.members)) {
      tripData.members.forEach((m) => {
        if (m.userId) memberIds.add(m.userId);
        if (m.id) memberIds.add(m.id);
      });
    }

    const senderId = alertData.senderMemberId || alertData.senderId || alertData.createdByMemberId;
    const senderUsername = alertData.createdByUsername || alertData.senderName || "A companion";

    const tokens = [];
    for (const memberId of memberIds) {
      // Exclude the sender
      if (memberId && memberId !== senderId) {
        const userDoc = await admin.firestore().collection("users").doc(memberId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData && userData.fcmToken) {
            tokens.push(userData.fcmToken);
          }
        }
      }
    }

    if (tokens.length === 0) {
      console.log("No recipient companion devices with FCM tokens to notify.");
      return null;
    }

    const payload = {
      notification: {
        title: "Proximity Alert!",
        body: `${senderUsername} is nearby or needs attention.`,
      },
      data: {
        tripId: tripId,
        alertId: context.params.alertId,
        type: "PROXIMITY_ALERT"
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: payload.notification,
        data: payload.data,
      });
      console.log(`Notifications sent to ${tokens.length} companion(s):`, response.successCount);
    } catch (error) {
      console.error("Error sending companion notifications:", error);
    }
    return null;
  });
