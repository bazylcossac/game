Launcher Corp Wars na Windows x64.

- **[CorpWars-Launcher.exe](https://github.com/bazylcossac/game/releases/download/launcher-v0.1.0/CorpWars-Launcher.exe)** — launcher na Windows, zalecany dla graczy. Instaluje aplikację, tworzy skróty i sprawdza dostępność WebView2. Nie wymaga uprawnień administratora.
- **CorpWars-Launcher-portable.exe** — uruchomienie bez instalatora; wymaga obecnego WebView2. Gra nadal ma jeden wspólny katalog instalacji w profilu użytkownika.
- **SHA256SUMS.txt** — sumy kontrolne pobranych plików.

Launcher pobiera wydania gry z publicznego GitHub Releases, sprawdza rozmiar i SHA-256, uruchamia grę i aktualizuje ją. Można śledzić najnowsze stabilne wydanie, wybrać kanał testowy „najnowsza” lub przypiąć starszą wersję. Przy zmianie wersji stary plik gry zostaje zastąpiony; zapisy i ustawienia pozostają. Aktualizacja czeka na zakończenie działającej gry.

Przy pierwszym uruchomieniu wybierz **Zainstaluj**. Instalacja gry: `%LOCALAPPDATA%\CorpWars\game`. Automatyczne aktualizacje działają, gdy launcher jest otwarty; przypięte wydanie nie zmienia się samoczynnie.

Pierwsze wydanie obsługuje pełne pobieranie paczek Windows x64. Po zamknięciu launchera niedokończony transfer zaczyna się od początku. Instalator nie ma jeszcze podpisu wydawcy Windows. Nowe wersje samego launchera pobiera się z Releases.

Starsze wydania gry mogą nie pasować do aktualnego serwera multiplayer. Wybierz kanał testowy, jeżeli serwer wymaga bieżącego buildu „najnowsza”.
