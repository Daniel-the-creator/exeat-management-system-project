// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// ============================================================================
// 1. AUTOMATIC EXPIRATION OF PENDING REQUESTS (After 3 Days)
// ============================================================================

/**
 * Scheduled function that runs every day at midnight
 * Marks pending requests as EXPIRED if they're older than 3 days
 */
exports.expirePendingRequests = functions.pubsub
  .schedule('0 0 * * *') // Runs at midnight every day
  .timeZone('Africa/Lagos')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const threeDaysAgo = new Date(now.toMillis() - 3 * 24 * 60 * 60 * 1000);

    try {
      // Find all pending requests older than 3 days
      const expiredRequestsSnapshot = await db.collection('exeatRequests')
        .where('status', 'in', ['PENDING_HOD', 'PENDING_SA', 'PENDING_WARDEN'])
        .where('expiresAt', '<=', admin.firestore.Timestamp.fromDate(threeDaysAgo))
        .get();

      if (expiredRequestsSnapshot.empty) {
        console.log('No expired requests found');
        return null;
      }

      // Batch update to mark as expired
      const batch = db.batch();
      expiredRequestsSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, {
          status: 'EXPIRED',
          lastUpdatedAt: now,
          expiredAt: now
        });
      });

      await batch.commit();
      console.log(`Expired ${expiredRequestsSnapshot.size} requests`);

      // Optional: Send notifications to students
      await notifyStudentsOfExpiredRequests(expiredRequestsSnapshot.docs);

      return null;
    } catch (error) {
      console.error('Error expiring requests:', error);
      throw error;
    }
  });

// ============================================================================
// 2. CLOUD FUNCTION: CREATE NEW EXEAT REQUEST
// ============================================================================

/**
 * Creates a new exeat request with priority scoring
 * Automatically sets expiration date to 3 days from creation
 */
exports.createExeatRequest = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { 
    studentId, 
    reason, 
    priorityLevel, 
    destination,
    leaveDate,
    returnDate,
    leaveTime,
    returnTime,
    phone,
    contactPerson,
    contactNumber,
    guardianApproval
  } = data;

  // Validate required fields
  if (!studentId || !reason || !priorityLevel) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Get student details
    const studentDoc = await db.collection('students').doc(studentId).get();
    if (!studentDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Student not found');
    }

    const student = studentDoc.data();
    const now = admin.firestore.Timestamp.now();
    const expiresAt = new Date(now.toMillis() + 3 * 24 * 60 * 60 * 1000); // 3 days from now

    // Calculate priority score
    const priorityScore = getPriorityScore(priorityLevel);

    // Create the request
    const requestData = {
      studentId,
      studentName: student.name,
      matricNumber: student.matricNumber,
      departmentId: student.departmentId,
      hallId: student.hallId,
      level: student.level,
      
      reason,
      priorityLevel,
      priorityScore,
      destination,
      leaveDate,
      returnDate,
      leaveTime,
      returnTime,
      phone,
      contactPerson,
      contactNumber,
      guardianApproval,
      
      status: 'PENDING_HOD', // Initial status
      currentStage: 'HOD',
      
      createdAt: now,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      lastUpdatedAt: now,
      
      // Approval tracking
      hodApproval: null,
      studentAffairsApproval: null,
      wardenApproval: null,
      
      // Approval details
      hodApprovalDetails: null,
      studentAffairsApprovalDetails: null,
      wardenApprovalDetails: null
    };

    const requestRef = await db.collection('exeatRequests').add(requestData);

    // Create notification for HOD
    await createNotification({
      recipientRole: 'HOD',
      departmentId: student.departmentId,
      type: 'NEW_REQUEST',
      title: 'New Exeat Request',
      message: `${student.name} has submitted a new ${priorityLevel} exeat request`,
      requestId: requestRef.id,
      priority: priorityScore
    });

    return { 
      success: true, 
      requestId: requestRef.id,
      expiresAt: expiresAt.toISOString()
    };
  } catch (error) {
    console.error('Error creating request:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// 3. CLOUD FUNCTION: APPROVE/REJECT REQUEST (with Sequential Enforcement)
// ============================================================================

/**
 * Handles approval/rejection of requests
 * Enforces sequential approval: HOD → Student Affairs → Hall Warden
 */
exports.processExeatRequest = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { requestId, action, adminId, comment } = data; // action: 'APPROVE' or 'REJECT'

  if (!requestId || !action || !adminId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Get admin details
    const adminDoc = await db.collection('admins').doc(adminId).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Admin not found');
    }

    const admin = adminDoc.data();
    const requestRef = db.collection('exeatRequests').doc(requestId);
    const requestDoc = await requestRef.get();

    if (!requestDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Request not found');
    }

    const request = requestDoc.data();
    const now = admin.firestore.Timestamp.now();

    // CRITICAL: Validate that admin can process this stage
    const validationResult = validateApprovalAuthority(admin, request);
    if (!validationResult.valid) {
      throw new functions.https.HttpsError('permission-denied', validationResult.message);
    }

    // Process based on action
    if (action === 'REJECT') {
      // Rejection can happen at any stage
      await requestRef.update({
        status: 'REJECTED',
        lastUpdatedAt: now,
        rejectedBy: adminId,
        rejectedByRole: admin.role,
        rejectionReason: comment || 'No reason provided',
        rejectedAt: now
      });

      // Notify student
      await createNotification({
        recipientId: request.studentId,
        recipientRole: 'STUDENT',
        type: 'REQUEST_REJECTED',
        title: 'Exeat Request Rejected',
        message: `Your exeat request has been rejected by ${admin.role}`,
        requestId
      });

      return { success: true, status: 'REJECTED' };
    }

    // APPROVAL LOGIC - Sequential Flow
    if (action === 'APPROVE') {
      const approvalDetails = {
        approvedBy: adminId,
        approvedByName: admin.name,
        approvedByRole: admin.role,
        approvedAt: now,
        comment: comment || null
      };

      let updateData = {
        lastUpdatedAt: now
      };

      // Determine next stage based on current stage
      if (request.status === 'PENDING_HOD') {
        updateData = {
          ...updateData,
          hodApproval: true,
          hodApprovalDetails: approvalDetails,
          status: 'PENDING_SA',
          currentStage: 'STUDENT_AFFAIRS'
        };

        // Notify Student Affairs
        await createNotification({
          recipientRole: 'STUDENT_AFFAIRS',
          type: 'NEW_REQUEST',
          title: 'New Exeat Request - HOD Approved',
          message: `${request.studentName} - ${request.priorityLevel} priority`,
          requestId,
          priority: request.priorityScore
        });

      } else if (request.status === 'PENDING_SA') {
        updateData = {
          ...updateData,
          studentAffairsApproval: true,
          studentAffairsApprovalDetails: approvalDetails,
          status: 'PENDING_WARDEN',
          currentStage: 'HALL_WARDEN'
        };

        // Notify Hall Warden
        await createNotification({
          recipientRole: 'HALL_WARDEN',
          hallId: request.hallId,
          type: 'NEW_REQUEST',
          title: 'New Exeat Request - SA Approved',
          message: `${request.studentName} - ${request.priorityLevel} priority`,
          requestId,
          priority: request.priorityScore
        });

      } else if (request.status === 'PENDING_WARDEN') {
        updateData = {
          ...updateData,
          wardenApproval: true,
          wardenApprovalDetails: approvalDetails,
          status: 'APPROVED',
          currentStage: 'COMPLETED',
          finalApprovedAt: now
        };

        // Notify Student - Final Approval
        await createNotification({
          recipientId: request.studentId,
          recipientRole: 'STUDENT',
          type: 'REQUEST_APPROVED',
          title: 'Exeat Request Approved! ✅',
          message: 'Your exeat request has been fully approved. Safe travels!',
          requestId
        });
      }

      await requestRef.update(updateData);
      return { success: true, status: updateData.status };
    }

    throw new functions.https.HttpsError('invalid-argument', 'Invalid action');

  } catch (error) {
    console.error('Error processing request:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// 4. HELPER FUNCTIONS
// ============================================================================

/**
 * Maps priority levels to numeric scores (lower = higher priority)
 */
function getPriorityScore(priorityLevel) {
  const priorityMap = {
    'EMERGENCY': 1,
    'MEDICAL': 2,
    'FAMILY': 3,
    'NORMAL': 4
  };
  return priorityMap[priorityLevel] || 4;
}

/**
 * Validates if an admin has authority to approve at current stage
 */
function validateApprovalAuthority(admin, request) {
  // HOD can only approve PENDING_HOD requests in their department
  if (request.status === 'PENDING_HOD') {
    if (admin.role !== 'HOD') {
      return { valid: false, message: 'Only HOD can approve at this stage' };
    }
    if (admin.departmentId !== request.departmentId) {
      return { valid: false, message: 'You can only approve requests from your department' };
    }
    return { valid: true };
  }

  // Student Affairs can approve PENDING_SA requests (institution-wide)
  if (request.status === 'PENDING_SA') {
    if (admin.role !== 'STUDENT_AFFAIRS') {
      return { valid: false, message: 'Only Student Affairs can approve at this stage' };
    }
    return { valid: true };
  }

  // Hall Warden can only approve PENDING_WARDEN requests in their hall
  if (request.status === 'PENDING_WARDEN') {
    if (admin.role !== 'HALL_WARDEN') {
      return { valid: false, message: 'Only Hall Warden can approve at this stage' };
    }
    if (admin.hallId !== request.hallId) {
      return { valid: false, message: 'You can only approve requests from your hall' };
    }
    return { valid: true };
  }

  return { valid: false, message: 'Request is not in a pending state' };
}

/**
 * Creates a notification document
 */
async function createNotification(notificationData) {
  const now = admin.firestore.Timestamp.now();
  
  return db.collection('notifications').add({
    ...notificationData,
    isRead: false,
    createdAt: now
  });
}

/**
 * Sends notifications to students about expired requests
 */
async function notifyStudentsOfExpiredRequests(expiredDocs) {
  const batch = db.batch();
  
  expiredDocs.forEach((doc) => {
    const request = doc.data();
    const notificationRef = db.collection('notifications').doc();
    
    batch.set(notificationRef, {
      recipientId: request.studentId,
      recipientRole: 'STUDENT',
      type: 'REQUEST_EXPIRED',
      title: 'Exeat Request Expired',
      message: 'Your exeat request has expired after 3 days without approval. Please submit a new request if needed.',
      requestId: doc.id,
      isRead: false,
      createdAt: admin.firestore.Timestamp.now()
    });
  });
  
  await batch.commit();
}

// ============================================================================
// 5. STATISTICS & ANALYTICS FUNCTIONS
// ============================================================================

/**
 * Get dashboard statistics for admins
 */
exports.getAdminStatistics = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { adminId } = data;

  try {
    const adminDoc = await db.collection('admins').doc(adminId).get();
    if (!adminDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Admin not found');
    }

    const admin = adminDoc.data();
    let query = db.collection('exeatRequests');

    // Apply filters based on admin role
    if (admin.role === 'HOD') {
      query = query.where('departmentId', '==', admin.departmentId);
    } else if (admin.role === 'HALL_WARDEN') {
      query = query.where('hallId', '==', admin.hallId);
    }
    // Student Affairs sees all requests (no filter needed)

    const allRequests = await query.get();

    // Calculate statistics
    const stats = {
      pending: 0,
      approved: 0,
      rejected: 0,
      expired: 0,
      total: allRequests.size,
      byPriority: {
        EMERGENCY: 0,
        MEDICAL: 0,
        FAMILY: 0,
        NORMAL: 0
      }
    };

    allRequests.docs.forEach(doc => {
      const request = doc.data();
      
      // Count by status
      if (request.status.includes('PENDING')) {
        stats.pending++;
      } else if (request.status === 'APPROVED') {
        stats.approved++;
      } else if (request.status === 'REJECTED') {
        stats.rejected++;
      } else if (request.status === 'EXPIRED') {
        stats.expired++;
      }

      // Count by priority
      if (request.priorityLevel in stats.byPriority) {
        stats.byPriority[request.priorityLevel]++;
      }
    });

    return stats;
  } catch (error) {
    console.error('Error getting statistics:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});