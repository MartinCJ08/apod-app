# APOD App

A Flutter (web + mobile) client for NASA's Astronomy Picture of the Day (APOD) API.

## What's inside
- Fetches APOD data by date
- Displays image or video (embeded YouTube)
- Shows title, explanation, media type, and copyright
- HD image toggle when available

## Notes
- Uses NASA's `API_KEY` dart define.
- This repo is intentionally lightweight and does **not** install Flutter. If you already have Flutter installed, the usual `flutter pub get` and `flutter run --dart-define=API_KEY=your_api_key_here -d chrome` will work.
- Build for production: `flutter build appbundle --dart-define=API_KEY=your_production_key`


## Acknowledgments & Attribution

Splash Icon
<a href="https://www.flaticon.es/iconos-gratis/satelite" title="satelite iconos">Satelite iconos creados por Infinite Dendrogram - Flaticon</a>