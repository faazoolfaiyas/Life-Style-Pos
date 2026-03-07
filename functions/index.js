const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// --- CONFIGURATION ---
const SETTINGS_COLLECTION = "bill_settings";
const SETTINGS_DOC = "config";
const ORIGIN_COLLECTION = "bill_origin";
const TEMP_COLLECTION = "temp_origin";
const BILLS_COLLECTION = "bills";

/**
 * Trigger: onCreate of a new Bill in the Master Record (bills).
 * Goal: Decide if this bill belongs in the "Transparency View" (Temp-Origin).
 */
exports.processNewBill = functions.firestore
  .document(`${BILLS_COLLECTION}/{billId}`)
  .onCreate(async (snap, context) => {
    const newBill = snap.data();
    const billId = context.params.billId;

    // 1. Get Settings (Target Value)
    const settingsDoc = await db.collection(SETTINGS_COLLECTION).doc(SETTINGS_DOC).get();
    const targetValue = settingsDoc.exists ? (settingsDoc.data().origin_target_value || 50000) : 50000;

    // 2. Get Current Date Range (12 AM - 12 AM)
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);

    // 3. Calculate Current Totals (Bill-Origin + Temp-Origin)
    // NOTE: In a high-volume app, we might want to store running totals. 
    // For now, querying is acceptable for < 1000 bills/day.
    
    // Fetch Verified Bills for today
    const originQuery = await db.collection(ORIGIN_COLLECTION)
      .where("timestamp", ">=", startOfDay)
      .where("timestamp", "<", endOfDay)
      .get();
      
    // Fetch Temp Bills for today
    const tempQuery = await db.collection(TEMP_COLLECTION)
      .where("timestamp", ">=", startOfDay)
      .where("timestamp", "<", endOfDay)
      .get();

    let currentTotal = 0;
    originQuery.forEach(doc => currentTotal += (doc.data().totalAmount || 0));
    
    const tempBills = []; // Keep track for swapping logic
    tempQuery.forEach(doc => {
      const data = doc.data();
      currentTotal += (data.totalAmount || 0);
      tempBills.push({ ...data, id: doc.id });
    });

    console.log(`[Algorithm] Target: ${targetValue}, Current Total: ${currentTotal}, New Bill: ${newBill.totalAmount}`);

    // 4. Decision Logic
    const newBillEntry = {
      billId: billId,
      date: newBill.createdAt, // String ISO or Timestamp
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      totalAmount: newBill.totalAmount,
      status: "pending"
    };

    if (currentTotal + newBill.totalAmount <= targetValue) {
      // CASE A: Under Target -> Add to Temp (Grow)
      console.log(`[Algorithm] Adding Bill ${billId} to Temp-Origin.`);
      await db.collection(TEMP_COLLECTION).doc(billId).set(newBillEntry);
    } else {
      // CASE B: Over Target -> Optimization / Swapping
      // "Remove a high-value bill and replace it with smaller bills"
      
      // Sort temp bills by value (Descending)
      tempBills.sort((a, b) => b.totalAmount - a.totalAmount);
      
      if (tempBills.length > 0) {
        const highestBill = tempBills[0];
        
        // Only swap if the new bill is SMALLER than the highest bill we have.
        // This reduces the total towards the target while keeping activity (or increasing activity if we implement multi-swap later).
        if (newBill.totalAmount < highestBill.totalAmount) {
           console.log(`[Algorithm] Swapping: Removing High-Value ${highestBill.billId} (${highestBill.totalAmount}) for New ${billId} (${newBill.totalAmount})`);
           
           const batch = db.batch();
           
           // Remove big bill
           batch.delete(db.collection(TEMP_COLLECTION).doc(highestBill.billId));
           
           // Add new small bill
           batch.set(db.collection(TEMP_COLLECTION).doc(billId), newBillEntry);
           
           await batch.commit();
        } else {
           console.log(`[Algorithm] New bill is too large (${newBill.totalAmount}). Ignoring.`);
        }
      } else {
         console.log(`[Algorithm] No temp bills to swap. Ignoring.`);
      }
    }
  });
