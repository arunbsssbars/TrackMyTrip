const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onProximityAlertCreated = functions.firestore
  .document("trips/{tripId}/proximity_alerts/{alertId}")
  .onCreate(async (snap, context) => {
    const alertData = snap.data();
    const tripId = context.params.tripId;

    if (!alertData) return;

    // Get all users in the trip (this assumes we have a way to know who is in the trip)
    // For simplicity, let's fetch all users from the 'users' collection who have fcmTokens
    // In a real app, you would query only the trip members.
    const usersSnapshot = await admin.firestore().collection("users").get();
    
    const tokens = [];
    usersSnapshot.forEach((doc) => {
      const user = doc.data();
      if (user.fcmToken && user.username !== alertData.createdByUsername) {
        tokens.push(user.fcmToken);
      }
    });

    if (tokens.length === 0) {
      console.log("No devices to notify.");
      return null;
    }

    const payload = {
      notification: {
        title: "Proximity Alert!",
        body: `${alertData.createdByUsername} is nearby or needs attention.`,
      },
      data: {
        tripId: tripId,
        alertId: context.params.alertId,
        type: "PROXIMITY_ALERT"
      },
    };

    try {
      const response = await admin.messaging().sendToDevice(tokens, payload);
      console.log("Notifications sent successfully:", response);
    } catch (error) {
      console.error("Error sending notifications:", error);
    }
    return null;
  });
