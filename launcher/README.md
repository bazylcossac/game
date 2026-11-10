# Corp Wars Launcher

Natywny launcher Windows x64: Tauri 2, Rust i lokalny interfejs bez zewnętrznych bibliotek UI. Odczytuje publiczne wydania `bazylcossac/game` bez tokenów i konta GitHub.

## Pobieranie

[Installer Windows](https://github.com/bazylcossac/game/releases/download/launcher-v0.1.0/CorpWars-Launcher-Setup.exe) · [Wydanie launchera](https://github.com/bazylcossac/game/releases/tag/launcher-v0.1.0)

Zalecany plik: `CorpWars-Launcher-Setup.exe`. Wydanie zawiera również pojedynczy EXE portable i sumy SHA-256. Launcher jest wydawany pod tagami `launcher-v*`; gra pod tagami `v*` i `najnowsza`. Opublikowanie launchera nie zmienia „latest” gry i nie uruchamia wdrożenia serwera.

## Działanie

- Pierwsza instalacja wymaga przycisku Zainstaluj. Dalej auto-update działa przy otwartym launcherze, gdy gra jest zamknięta; można go wyłączyć.
- Najnowsze stabilne wydanie, testowy `najnowsza` albo przypięta konkretna paczka. Przypięcie jest zapisywane i przetrwa restart. Zmiana assetu pod tym samym tagiem jest wykrywana po jego tożsamości.
- Jeden zarządzany plik gry: `%LOCALAPPDATA%/CorpWars/game/MieczDawida-windows.exe`. Każde wydanie zastępuje poprzednie; powrót do starszego oznacza nowe pobranie.
- Plik tymczasowy w `updates/game.download` jest sprawdzany przed podmianą. SHA-256, rozmiar i format Windows PE x64 muszą się zgadzać. Podczas transferu potrzebne jest miejsce na obecny i nowy plik.
- Blokada pojedynczej instancji, dziennik transakcji i odzyskiwanie przerwanej podmiany. Aktualizacja czeka na zamknięcie gry; działająca gra nie jest kończona.
- Zapisy gry `user://` są poza katalogiem zarządzanym. Launcher ich nie usuwa, nie migruje i nie usuwa innych kopii gry z komputera.
- Offline uruchamia zweryfikowaną obecną instalację i pokazuje wiek katalogu z cache. GitHub API ma limity; po ich przekroczeniu należy poczekać.

Wydanie 0.1.0 nie obsługuje aktualizacji różnicowych, macOS, podpisanych manifestów wydawcy ani samodzielnej aktualizacji EXE launchera. Nowe wydanie launchera pobiera się z Releases. Pauza zachowuje transfer tylko w otwartej aplikacji; po przerwaniu pobierania przez zamknięcie/awarię pobranie zaczyna się od zera. Zwykłe zamknięcie okna podczas aktualizacji wymaga jej anulowania lub dokończenia.

## Budowanie

Windows, Node.js 22+, Rust stable, Microsoft C++ Build Tools i WebView2:

```powershell
cd launcher
npm ci
npm run check
cargo test --locked --manifest-path src-tauri/Cargo.toml
npm run build
```

Gotowy instalator: `src-tauri/target/release/bundle/nsis/`. Nie potrzeba Godota do budowania launchera. `Cargo.lock` i `package-lock.json` są wersjonowane.

Test integracyjny pobiera dwie rzeczywiste paczki gry do **tymczasowego katalogu**, sprawdza instalację, downgrade, pozostawienie jednego EXE oraz przypięcie po restarcie. Katalog jest sprzątany po teście:

```powershell
cargo test --locked --manifest-path src-tauri/Cargo.toml live_github_install_and_downgrade -- --ignored --nocapture
```

## Publikacja

Workflow `.github/workflows/launcher.yml` buduje Windows po zmianach launchera na `main`. Tag `launcher-vX.Y.Z` buduje i publikuje instalator, portable i `SHA256SUMS.txt` w Releases tego samego repozytorium. Pierwszy launcher jest publikowany ze swojej gałęzi `launcher/windows`, bez przenoszenia nieopublikowanych zmian gry desktopowej i portu Web do `main`. Przed tagiem należy zmienić wersję w `package.json`, `src-tauri/Cargo.toml`, `tauri.conf.json`, odświeżyć lockfile i przygotować `RELEASE_NOTES.md`.

Pełny projekt: [docs/LAUNCHER_PLAN.md](../docs/LAUNCHER_PLAN.md). Zachowana makieta w `docs/design` przedstawia wcześniejszą symulację; właściwa aplikacja znajduje się w tym katalogu.
