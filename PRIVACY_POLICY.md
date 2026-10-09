# Privacy Policy for TrackMyTrip

**Last Updated:** October 10, 2026

## 1. Introduction
TrackMyTrip ("we", "our", or "the App") is committed to protecting your privacy. This Privacy Policy explains how our mobile application handles user information, location coordinates, media files, and authentication credentials.

TrackMyTrip does **not** monetize user data, does **not** sell personal data to third parties, and does **not** include advertising networks or tracking libraries.

---

## 2. Information We Collect and Why

### A. Location Information (Precise & Background Location)
- **What is collected:** Real-time GPS coordinates (latitude, longitude, speed, and heading) during an active trip.
- **Purpose:** 
  1. Live convoy tracking: Displaying your location to verified co-travelers in your private trip room.
  2. Proximity and SOS safety alerts: Notifying companions if members stray beyond a safe distance.
  3. Milestone journaling: Tagging route stoppage points and trip itineraries.
- **User Control:** You may disable live tracking or toggle **Privacy Coordinate Fuzzing** at any time. When a trip is paused or ended, GPS broadcasting immediately halts.

### B. Photos and Media Memories
- **What is collected:** Photos and receipt images that you explicitly choose to upload to trip albums or expense records.
- **Storage:** Media is securely optimized on-device and stored in our dedicated cloud storage repository (Cloudinary) and local device cache. Media is only visible to authenticated members of your private trip.

### C. Authentication & Account Credentials
- **What is collected:** Email address, display name, and unique user identifier (UID) via Firebase Authentication or Google Sign-In.
- **Storage:** Sensitive local tokens are encrypted using platform hardware keystores (Android Keystore / iOS Keychain AES-256 GCM).

### D. Financial and Expense Records
- **What is collected:** Amounts, categories, and payer allocations recorded during trip expense splitting.
- **Storage:** Synchronized directly to your private trip room database.

---

## 3. Third-Party Services
TrackMyTrip integrates with trusted cloud infrastructure providers strictly for core functionality:
- **Google Firebase (Firestore, Realtime Database, Authentication):** For real-time database synchronization and secure login.
- **Cloudinary:** For cloud media storage with strict 25 GB quota bounds and binary header validation.
- **Google Sign-In:** For secure authentication without password sharing.

None of these providers receive data for advertising or cross-app tracking.

---

## 4. Data Retention and Account Deletion
You maintain complete control over your data:
- **Right to Erasure (GDPR / CCPA / Store Compliance):** You can permanently delete your account and all associated trips, expenses, stoppage points, and photos directly in the App via **Profile $\rightarrow$ Account & Security $\rightarrow$ Delete Account & Purge Data**.
- Deletion is instantaneous and permanent from both your local device and cloud servers.

---

## 5. Security Safeguards
- **Zero Raw Query Injections:** All local SQLite databases use parameterized queries.
- **Payload & Rate Limiting:** All cloud endpoints enforce rate limiting to defend against brute force attacks.
- **File Integrity:** Raw image headers are verified with magic byte inspection.

---

## 6. Contact Us
For questions regarding this policy or privacy inquiries, contact the developer at:
- **Email:** arunbsssbars@gmail.com
- **Project Repository:** https://github.com/arunbsssbars/TrackMyTrip
