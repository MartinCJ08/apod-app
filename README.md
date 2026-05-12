# APOD App

A Flutter (web + mobile) client for NASA's Astronomy Picture of the Day (APOD) API.

## What's inside
- Fetches APOD data by date
- Displays image or video (embeded YouTube)
- Shows title, explanation, media type, and copyright
- HD image toggle when available

## Notes
- Uses NASA's `DEMO_KEY`. For higher rate limits, replace the key in `lib/main.dart`.
- This repo is intentionally lightweight and does **not** install Flutter. If you already have Flutter installed, the usual `flutter pub get` and `flutter run -d chrome` will work.
