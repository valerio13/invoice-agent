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
flutter analyze && flutter test
```
