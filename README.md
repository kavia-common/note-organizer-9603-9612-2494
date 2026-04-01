# Unified Flutter Notes App (sqflite + Riverpod)

This repository contains a unified Flutter implementation of the offline-first Notes app, combining requirements from the prior native iOS (Swift) and Android (Kotlin) implementations.

## Stack
- Local persistence: `sqflite` (SQLite)
- State management: `flutter_riverpod`
- Reactive reads: `Stream` (SQLite change notifications -> query streams)
- Commands / sync: `Future` (CRUD + manual sync trigger)
- Formatting: `intl`

## Features
- Create, edit, delete notes (offline-first)
- Reactive notes list (updates immediately on DB writes)
- Search notes (simple text filter)
- Sync skeleton (last-write-wins merge ready; remote API is an interface + stub)

## Run
From `notes_frontend/`:

```bash
flutter pub get
flutter run
```

## Project structure
- `lib/app/` app setup (theme/router)
- `lib/domain/` domain models
- `lib/data/` database, DAOs, repository, sync abstraction
- `lib/features/` UI screens + controllers (Riverpod)

"""
