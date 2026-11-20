# Desktop app

Flutter desktop app of the invoice agent, macOS first. It only talks to the backend REST API: it holds no business logic, no database access and no keys.

## Run

Start the backend first (see the main README), then:

```bash
flutter run -d macos --dart-define=API_URL=http://127.0.0.1:8000
```

`API_URL` defaults to `http://127.0.0.1:8000`.

## Checks

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze && flutter test
flutter test integration_test -d macos   # in the real app
```

`dart format` uses a width of 100, set in `analysis_options.yaml`. The CI runs the first two lines on Linux; the real-app test needs a Mac.
