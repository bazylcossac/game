Launcher Corp Wars na Windows x64.

**Nowe w 0.2.0:** w zakładce Wersje jest lista „Buildy testowe z panelu” — każdy build zlecony z panelu zadań pojawia się tam od razu i można go wybrać albo przypiąć. „Najnowszy build testowy” zawsze instaluje ostatni z nich.

- **CorpWars-Launcher-Setup.exe** — zalecany instalator. Tworzy skróty i sprawdza dostępność WebView2. Nie wymaga uprawnień administratora.
- **CorpWars-Launcher-portable.exe** — uruchomienie bez instalatora; wymaga obecnego WebView2. Gra nadal ma jeden wspólny katalog instalacji w profilu użytkownika.
- **SHA256SUMS.txt** — sumy kontrolne pobranych plików.

Launcher pobiera wydania gry z publicznego GitHub Releases, sprawdza rozmiar i SHA-256, uruchamia grę i aktualizuje ją. Można śledzić najnowsze stabilne wydanie, śledzić najnowszy build testowy, wybrać dowolny build testowy z panelu lub przypiąć starszą wersję. Przy zmianie wersji stary plik gry zostaje zastąpiony; zapisy i ustawienia pozostają. Aktualizacja czeka na zakończenie działającej gry.

Przy pierwszym uruchomieniu wybierz **Zainstaluj**. Instalacja gry: `%LOCALAPPDATA%\CorpWars\game`. Automatyczne aktualizacje działają, gdy launcher jest otwarty; przypięte wydanie nie zmienia się samoczynnie.

Pierwsze wydanie obsługuje pełne pobieranie paczek Windows x64. Po zamknięciu launchera niedokończony transfer zaczyna się od początku. Instalator nie ma jeszcze podpisu wydawcy Windows. Nowe wersje samego launchera pobiera się z Releases.

Starsze wydania gry mogą nie pasować do aktualnego serwera multiplayer. Wybierz kanał testowy, jeżeli serwer wymaga bieżącego buildu „najnowsza”.
