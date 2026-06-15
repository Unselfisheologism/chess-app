# Chess App — Learn chess, unlock your phone

A daily chess learning app that locks social media until you complete today's lesson. Built with Flutter. iOS first, Android second.

> **Status:** MVP in development.
> Full spec: [`docs/plans/2026-06-15-001-feat-chess-duolingo-skill-app-plan.md`](docs/plans/2026-06-15-001-feat-chess-duolingo-skill-app-plan.md)

## Planned features (MVP)

- **Daily micro-lesson** — 10–15 min, hand-designed Duolingo-style flow with 5–8 lesson types
- **Stockfish-powered play** — offline chess engine, 600 → 3000 ELO difficulty
- **Social media lock** — iOS Screen Time API (Family Controls) blocks your chosen apps until today's lesson is done
- **Streaks + freeze tokens** — daily streak; play a match to earn a streak-freeze token
- **Free tier** — first 3 lessons free; subscription unlocks everything

## Stack

Flutter 3.22 / Dart 3.4 · `stockfish_for_flutter` (Dart FFI) · `flutter_family_controls` (iOS Screen Time) · `lottie` · `purchases_flutter` (RevenueCat)

## Run

```bash
flutter pub get
flutter run
```

## Roadmap

- **MVP (30 days):** Lesson loop, Stockfish play, iOS lock, paywall, 30 lessons of content
- **v2 (60 days):** Android lock via Accessibility Services, optional Lichess API for real opponents
- **v3:** Cloud sync, push notifications, iPad layout, leaderboards, additional sub-domains (math, music)

---

Forked from [man-wen](https://github.com/Unselfisheologism/man-wen) — same Flutter build setup, different product.
