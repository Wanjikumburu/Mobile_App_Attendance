// functions/index.js
// Firebase Cloud Functions for AttendX v2
// Deploy with: firebase deploy --only functions

const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// ────────────────────────────────────────────────────────────────
// AUTO-CLOSE SESSION
// Runs every minute — closes sessions that have expired
// ────────────────────────────────────────────────────────────────
exports.autoCloseSessions = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const now       = admin.firestore.Timestamp.now();
    const snapshot  = await db.collection('sessions')
      .where('status', '==', 'open')
      .get();

    const batch = db.batch();

    snapshot.docs.forEach(doc => {
      const data     = doc.data();
      const openedAt = data.openedAt.toDate();
      const duration = data.durationMinutes || 5;
      const closesAt = new Date(openedAt.getTime() + duration * 60 * 1000);

      if (new Date() > closesAt) {
        batch.update(doc.ref, {
          status:   'closed',
          closedAt: now,
        });
        console.log(`Auto-closed session: ${doc.id}`);
      }
    });

    await batch.commit();
    return null;
  });

// ────────────────────────────────────────────────────────────────
// CHECK AT-RISK STUDENTS
// Triggers when an attendance record is written
// If student drops below 75%, creates an alert
// ────────────────────────────────────────────────────────────────
exports.checkAtRisk = functions.firestore
  .document('attendance/{recordId}')
  .onCreate(async (snap, context) => {
    const record  = snap.data();
    const userId  = record.userId;
    const classId = record.classId;

    try {
      // Get class total sessions
      const classDoc = await db.collection('classes').doc(classId).get();
      if (!classDoc.exists) return null;
      const totalSessions = classDoc.data().totalSessions || 0;
      if (totalSessions === 0) return null;

      // Count this student's attendance
      const attendanceSnap = await db.collection('attendance')
        .where('userId',  '==', userId)
        .where('classId', '==', classId)
        .where('status',  'in', ['present', 'late', 'excused'])
        .get();

      const attended   = attendanceSnap.docs.length;
      const percentage = Math.round((attended / totalSessions) * 100);

      console.log(`${userId} in ${classId}: ${percentage}%`);

      // If below 75%, create alert
      if (percentage < 75) {
        // Check if unread alert already exists
        const existing = await db.collection('alerts')
          .where('userId',  '==', userId)
          .where('classId', '==', classId)
          .where('type',    '==', 'at_risk')
          .where('read',    '==', false)
          .get();

        if (!existing.empty) return null; // already alerted

        await db.collection('alerts').add({
          userId:    userId,
          classId:   classId,
          className: classDoc.data().name || '',
          type:      'at_risk',
          title:     'Attendance At Risk ⚠️',
          message:   `Your attendance in ${classDoc.data().name} is ${percentage}%. Minimum required is 75%.`,
          read:      false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Also send push notification if FCM token exists
        const userDoc = await db.collection('users').doc(userId).get();
        const fcmToken = userDoc.data()?.fcmToken;

        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: 'Attendance At Risk ⚠️',
              body:  `Your ${classDoc.data().name} attendance is ${percentage}%`,
            },
            data: { classId, type: 'at_risk' },
          });
        }
      }

      return null;
    } catch (error) {
      console.error('checkAtRisk error:', error);
      return null;
    }
  });

// ────────────────────────────────────────────────────────────────
// INCREMENT SESSION COUNT ON CLASS
// When a session closes, increment totalSessions on the class
// ────────────────────────────────────────────────────────────────
exports.incrementSessionCount = functions.firestore
  .document('sessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    // Only fire when status changes from 'open' to 'closed'
    if (before.status === 'open' && after.status === 'closed') {
      const classId = after.classId;
      await db.collection('classes').doc(classId).update({
        totalSessions: admin.firestore.FieldValue.increment(1),
      });
      console.log(`Incremented totalSessions for class: ${classId}`);
    }

    return null;
  });
