Firebase integration checklist for institution-payment-system

1) Hosting (Web)
- Already configured in repo: .firebaserc (project: institution-payment-system) and firebase.json (SPA rewrites + caching). 
- Build your Flutter web app to build/web and deploy via Firebase Hosting in your environment.

2) Register Firebase apps
- In the Firebase Console, open the institution-payment-system project and add 3 apps: Android, iOS, and Web.
- Capture these values/files and share them (privately) so we can wire them into the project:
  - Web (FirebaseConfig): apiKey, authDomain, projectId, storageBucket, messagingSenderId, appId, measurementId (optional)
  - Android: google-services.json (for applicationId: e.g., com.yourorg.institution)
  - iOS: GoogleService-Info.plist (for bundle identifier, e.g., com.yourorg.institution)

3) Android wiring (once google-services.json is available)
- Place google-services.json at android/app/google-services.json
- Ensure android/build.gradle has classpath 'com.google.gms:google-services:4.4.2' in buildscript dependencies, and android/app/build.gradle applies plugin: 'com.google.gms.google-services'.

4) iOS wiring (once GoogleService-Info.plist is available)
- Add GoogleService-Info.plist to ios/Runner/ and ensure it is included in the Runner target.

5) Web wiring (once FirebaseConfig is available)
- Initialize Firebase in Dart using firebase_core with FirebaseOptions matching the Web config, or use the FlutterFire CLI to generate firebase_options.dart.

Note: No runtime Firebase packages have been added yet to avoid breaking builds without credentials. After you provide the app configs, we will: (a) add firebase_core to pubspec, (b) initialize Firebase in main.dart guarded for web/mobile, and (c) commit platform plugin changes for Android/iOS.
