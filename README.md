# SpendSnap

A Flutter MVP for automatic-feeling personal expense tracking.

## Included
- Home dashboard
- Income/expense transactions
- Local persistence with SharedPreferences
- Budget setting
- Category analytics
- Light/dark theme
- Android/iOS-compatible Flutter UI

## Run
1. Install Flutter and Android Studio/Xcode.
2. Run `flutter pub get`.
3. Run `flutter run`.

## Next production integrations
- Firebase Auth + Firestore
- Android transaction/SMS/notification ingestion subject to platform and store policies
- iOS-compatible bank/payment data integration where permitted
- Merchant classification
- Spending insights
- What-if affordability simulator

## Phone-only cloud build

This repository includes `.github/workflows/build-apk.yml`. GitHub Actions builds the Android APK in the cloud, so a PC is not required.

After uploading the project to GitHub:
1. Open the repository.
2. Open **Actions**.
3. Select **Build SpendSnap APK**.
4. Tap **Run workflow**.
5. Open the completed run.
6. Under **Artifacts**, download `spendsnap-release-apk`.
7. Extract the downloaded ZIP and install `app-release.apk` on Android.
