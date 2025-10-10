 WorkStudy Mobile App

### Overview

**WorkStudy** is a Flutter-based mobile application designed to streamline the **Work-Study Programme** by connecting students and supervisors. The app allows students to **log work hours**, **track attendance**, and **submit time entries** for supervisor approval. Supervisors can review, approve, or reject entries, while both roles maintain clear visibility over total hours worked.

The system helps institutions manage student work records digitally, reducing manual paperwork and improving accountability.

---

### Features

#### 👨‍🎓 Student Role

* **Login & Signup** using Firebase Authentication.
* **Time In / Time Out** using an interactive time picker and calendar.
* **Session Logging** — each work session is stored for approval.
* **Dashboard View** with:

  * Total hours worked (after supervisor approval).
  * Pending approvals.
  * Notifications for approved/rejected logs.

#### 🧑‍🏫 Supervisor Role

* **Login / Authentication** via Firebase.
* **View Student Logs** — all pending and approved sessions.
* **Approve / Decline Work Sessions**.
* **Real-time Notifications** when new logs are submitted.
* **Automatic Hour Summation** after approval.

#### ⚙️ System Features

* **Firebase Authentication** — for secure login and signup.
* **Cloud Firestore** — to store user data, work logs, and approvals.
* **Push Notifications** — alert supervisors on new submissions.
* **Responsive UI** — consistent across Android and iOS.
* **Header Branding** — “WORK STUDY” text visible on all pages except login/signup.
* **Educational Theme** — light blue interface with minimal, clean UI.

---

### App Flow

1. **Signup / Login**

   * Users select their role (Student or Supervisor).
   * Firebase handles authentication securely.

2. **Student Actions**

   * Student logs in → taps *Time In* → performs task → taps *Time Out*.
   * Entry is stored in Firestore and marked “Pending Approval.”
   * Supervisor receives a notification for review.

3. **Supervisor Actions**

   * Supervisor logs in → sees pending logs.
   * Approves or declines submissions.
   * Upon approval, student’s total hours update automatically.

4. **Notification System**

   * Students are notified when logs are approved or rejected.
   * Supervisors are notified on new student submissions.

---

### Tech Stack

| Layer         | Technology / Package                        | Description                              |
| ------------- | ------------------------------------------- | ---------------------------------------- |
| Frontend      | **Flutter (Dart)**                          | Cross-platform mobile framework          |
| Backend       | **Firebase**                                | Cloud-based backend for auth and storage |
| Database      | **Cloud Firestore**                         | Stores users, work logs, and approvals   |
| Notifications | **Firebase Cloud Messaging (FCM)**          | Real-time alerts                         |
| UI Styling    | **Material Design Widgets + Custom Colors** | Consistent theme & layout                |

---

### Folder Structure

```
/lib
├── main.dart
├── pages/
│   ├── login.dart
│   ├── signup.dart
│   ├── forgotpasswordpage.dart
│   ├── newpasswordpage.dart
│   ├── student_dashboard.dart
│   ├── supervisor_dashboard.dart
│   └── widgets/
│       ├── time_picker.dart
│       └── calendar.dart
└── services/
    ├── firebase_auth_service.dart
    └── firestore_service.dart
```

---

### How to Run Locally

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/workstudy-flutter.git
   cd workstudy-flutter
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Connect Firebase**

   * Add your Firebase project files:

     * `google-services.json` (Android)
     * `GoogleService-Info.plist` (iOS)
   * Enable Firebase Authentication and Firestore.

4. **Run the app**

   ```bash
   flutter run
   ```

---

### Pending / Future Enhancements

* Add user profile editing.
* Export work logs (PDF or CSV).
* Implement in-app chat between students and supervisors.
* Add institution admin role.
* Integrate biometric sign-in (fingerprint/face ID).
* Offline logging (sync when reconnected).

---

### Credits

**Developer:** Ramon Kamau
**Institution:** Daystar University
**Project:** Work-Study Programme Support System
**Email:** [Your Email Here]
**Version:** 1.0.0

---

> “Practice makes mastery — continuous improvement builds expertise.”


