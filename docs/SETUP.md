# Setup guide

Estimated time: 20 minutes.

## Requirements

- Flutter 3.29 or newer (Dart 3.7+). Check with `flutter --version`.
- A free Supabase account: https://supabase.com
- Optional, for the SQL tests: Node.js 18+

## 1. Create the Supabase project

1. Create a new project in the Supabase dashboard.
2. Open **Project Settings -> API** and copy the **Project URL** and the
   **anon public** key. Never use the `service_role` key in the app.

## 2. Apply the database migrations

Apply the files in `supabase/migrations` in order (they are numbered):

```
20260101000001_core_schema.sql
20260101000002_permissions_and_helpers.sql
20260101000003_integrity_triggers.sql
20260101000004_workflow_triggers.sql
20260101000005_row_level_security.sql
20260101000006_bootstrap_functions.sql
20260101000007_app_rpcs.sql
20260101000008_storage.sql
20260101000009_realtime.sql
```

Either method works:

- **Supabase CLI:** `supabase link --project-ref YOUR-REF` then `supabase db push`.
- **SQL editor:** open each file in order and run it.

The storage migration creates four buckets: `org-assets` (company logo) and
`avatars` (profile photos) are public so images load without signed URLs;
`employee-documents` and `notice-attachments` are private and are opened with
short-lived signed URLs. Write access to every bucket is limited by policy to
the caller's own organization folder. The realtime migration adds the
notification table to the realtime publication.

## 3. Configure authentication

In **Authentication -> Providers** keep E-mail enabled.

- **Confirm e-mail:** you can leave it on for production. The app handles
  both cases: with confirmation on, the new owner confirms by e-mail and then
  signs in. For quick local testing you can switch it off.
- **Site URL and redirect URLs** (Authentication -> URL Configuration): add the
  URL where the web app will run, for example `http://localhost:3000` while
  developing. Password reset links return to this address.

## 4. Generate the platform folders

```bash
./setup.sh
```

This runs `flutter create` for Android, iOS and Web, installs packages, adds
the Android INTERNET permission and the iOS photo and camera descriptions.

On Windows, run the same steps by hand:

```powershell
flutter create . --platforms=android,ios,web --project-name ez_workforce --org com.ezworkforce
flutter pub get
```

Then add `<uses-permission android:name="android.permission.INTERNET" />`
above `<application` in `android/app/src/main/AndroidManifest.xml`, and add
`NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription` strings to
`ios/Runner/Info.plist`. Delete `test/widget_test.dart` if Flutter generated it.

## 5. Run the app

The keys are passed at build time with `--dart-define`; nothing is stored in
the repository.

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

Use `-d <device-id>` for a phone or emulator (`flutter devices` lists them).
If the keys are missing the app shows a setup screen instead of crashing.

### Production web build

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Serve `build/web` from any static host. Single page app routing needs the
host to fall back to `index.html` for unknown paths.

## 6. First sign-in

1. Open the app and choose **Create organization**.
2. Register with your name, e-mail, password and company name. You become the
   Owner and the organization starts on a 14 day trial with default roles,
   a head office branch and an onboarding checklist.
3. In **Employees -> Add employee** create people. Each new person gets an
   invite code. They choose **Join with invite code** on the sign-in screen
   to create their login.

## 7. Optional: scheduled notices

Scheduled notices are published when someone opens the app. To publish them
on time even when nobody is online, enable the `pg_cron` extension
(Database -> Extensions) and schedule
`select public.dispatch_due_notice_notifications();` every 5 minutes.

## Running the tests

```bash
# SQL: migrations, triggers, RLS, RPCs (95 assertions)
cd tool && npm install && npm test

# Dart unit tests
flutter test
```

## First run checklist

The Dart code has not been compiled in the environment where it was written.
Run these before anything else and fix what they report:

1. `flutter pub get`
2. `flutter analyze` - expect a few type or deprecation findings; unused
   import warnings are harmless and can be removed.
3. `flutter test`
4. Sign up, create an employee, publish a notice, edit a role and confirm that
   an Employee login cannot see the Roles or Audit pages.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Setup screen appears at launch | The `--dart-define` keys are missing or empty |
| "Failed host lookup" on Android | The INTERNET permission is missing from the manifest |
| Sign-up works but the app stays on the activation screen | The e-mail address is not confirmed yet, or the migrations were not applied in order |
| Image or file upload fails | Migration 8 (storage) was not applied, or the bucket policies were edited |
| Notice images do not load on web | Check the storage bucket CORS settings in Supabase |
