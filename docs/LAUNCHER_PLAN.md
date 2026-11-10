# Corp Wars — plan launchera desktopowego

Status: wdrożony pierwszy launcher Windows x64 `0.1.0`, 10 listopada 2026. Kod i instrukcja budowania: [launcher/README.md](../launcher/README.md). Pobieranie i zastępowanie rzeczywistych paczek GitHub przeszło test integracyjny. Zakres: lokalna gra desktopowa, wydania z GitHub Releases. Launcher pobiera całą paczkę desktopową; ograniczenie portu Web do jednej mapy nie dotyczy tego produktu.

Makieta: [design/corp-wars-launcher.html](design/corp-wars-launcher.html). Przyciski, wybór wydania i postęp działają jako symulacja; niczego nie pobierają, nie uruchamiają i nie usuwają na komputerze.

W makiecie scenariusze wybiera się na dole okna. Pobieranie zaczyna się przyciskiem, żeby można było obejrzeć stan przed aktualizacją; produkcyjny auto-update ma rozpoczynać je sam zgodnie z ustawieniami. Przełączniki ustawień pokazują wybór preferencji, nie sterują rzeczywistym systemem Windows.

## 1. Ustalenia na podstawie istniejącego projektu

- Branding w `scripts/core/c.gd`: **CORP WARS / OSTATNI BUNT LUDZI**, wersja źródeł `0.13.0`.
- Repozytorium `bazylcossac/game` jest już **publiczne**; potwierdzono anonimowym odczytem API przed wdrożeniem. Launcher korzysta z jego Releases bez tokenu. W czasie pierwotnego projektowania repo było prywatne; ta przeszkoda została usunięta przez właściciela.
- `.github/workflows/build.yml` publikuje Windows jako pojedynczy `MieczDawida-windows.exe`; preset Windows osadza PCK. To ułatwia wymianę gry bez pozostawiania starych zasobów. Nazwa pliku nadal pochodzi od poprzedniej nazwy gry.
- Workflow publikuje trwałe wydania dla tagów `v*`, a po zmianach `main` usuwa i tworzy ponownie testowe wydanie `najnowsza`. Ten tag nie jest trwałym identyfikatorem buildu.
- Ten sam workflow wdraża serwer z `main`. Najnowsze stabilne wydanie klienta nie musi odpowiadać aktualnemu serwerowi. Przed dystrybucją trzeba ustalić zgodność klient–serwer i opisać ją w metadanych/protokole; samo uruchomienie EXE nie potwierdza działającego multiplayera.

Odczytany katalog wydań, stan na 10.11.2026:

| Wydanie | Kanał | Data publikacji UTC | Windows | Tożsamość paczki Windows |
| --- | --- | --- | --- | --- |
| `v0.12.0` | stabilny | 07.11, 10:47 | 195 084 032 B ≈ 186,0 MiB | release `437510694`, asset `720412743` |
| `v0.11.0` | stabilny | 07.11, 09:24 | 195 052 464 B ≈ 186,0 MiB | release `437467507`, asset `720221363` |
| `najnowsza` | testowy, zmienny | 07.11, 10:54 | 195 084 288 B ≈ 186,0 MiB | release `437514106`, asset `720427368`, commit `f3c0903` |

`v0.13.0` nie było w odczytanym katalogu Releases. Numer w kodzie nie jest dowodem opublikowania paczki. Makieta używa rzeczywistych wydań; przedstawia nowy branding launchera również przy starszych paczkach gry.

## 2. Zasady produktu

1. **Jedna instalacja gry, jeden plik startowy, jeden aktywny numer wersji.** Nie tworzymy biblioteki zainstalowanych wersji, folderów `v0.11/`, `v0.12/` ani trwałych kopii `.old`.
2. **Domyślnie: najnowsze stabilne wydanie.** Launcher sprawdza katalog po otwarciu. Jeśli gra jest zamknięta i automatyczne aktualizacje włączone, pobiera, sprawdza i instaluje aktualizację. Nie wymaga osobnej zgody na każdą zwykłą aktualizację.
3. **Ręczny wybór przypina wydanie.** Wybranie `v0.11.0` oznacza „pozostań na 0.11.0”, a nie „przy następnym otwarciu wróć do 0.12.0”. Powrót do aktualizacji wymaga wyboru „Najnowsza stabilna”.
4. **Kanał testowy jest świadomym wyborem.** Śledzi `najnowsza`, pokazuje krótki commit i datę, nie udaje numerowanej stabilnej wersji. Nie da się wybierać historycznych buildów testowych, które zostały usunięte z GitHub.
5. **Nowa paczka najpierw jest pobierana i sprawdzana, potem zastępuje starą.** Plik tymczasowy nie jest drugą instalacją i nie ma przycisku uruchomienia. Po sukcesie stary plik i pozostałości transakcji znikają.
6. **Zapisy, ustawienia i logi gracza pozostają.** Usuwanie starego EXE nie oznacza usuwania danych użytkownika. Starsza gra może nie rozumieć nowszego formatu zapisów — nie obiecujemy zgodności wstecznej.
7. **Działająca gra blokuje podmianę.** Launcher nie kończy procesu gracza. Może przygotować paczkę, lecz instaluje ją dopiero po zamknięciu gry.
8. **Offline można uruchomić sprawną, zainstalowaną grę.** Brak odpowiedzi GitHub nie oznacza „masz najnowszą wersję”; interfejs pokazuje czas ostatniego sprawdzenia. Dostępność funkcji sieciowych zależy od gry.

Zasada jednej kopii dotyczy instalacji zarządzanej przez launcher. Nie skanujemy i nie kasujemy samodzielnie innych EXE gracza z Pulpitu lub Pobranych. Ewentualny import istniejącej kopii będzie osobnym, jawnym przeniesieniem wskazanego pliku, a nie kopią wykonywaną w tle.

## 3. Wygląd i widoki

Kierunek: oszczędny launcher w klimacie Corp City. Duży, nieruchomy kadr neonowego miasta z istniejącego `assets/textures/menu/map_neonowa_dzielnica.jpg`, mocny logotyp, proste powierzchnie, jeden dominujący przycisk. Bez renderowania sceny Godota, animowanego wideo i automatycznej muzyki. Domyślny motyw ciemny, wariant jasny zgodny z systemem; makieta reaguje na motyw hosta.

Docelowe okno około 1100 × 740, minimalne 760 × 600, obsługa DPI 125–200%. Wąski wariant makiety służy także oglądaniu projektu w rozmowie. Font interfejsu: Segoe UI/systemowy; nagłówek marki mocny, skondensowany. Czytelne stany focus, tekstowe etykiety statusów, brak informacji przekazywanej wyłącznie kolorem.

| Widok | Zawartość | Główna akcja |
| --- | --- | --- |
| **Graj** | Kadr miasta, zainstalowana wersja, wybrany tryb aktualizacji, dostępne wydanie, krótkie informacje o zmianach | `Graj`, `Zainstaluj` albo `Aktualizuj`, zależnie od stanu |
| **Wersje** | Najnowsza stabilna, kanał testowy, lista opublikowanych wydań, data, rozmiar, etykieta „Zainstalowana” | Wybierz wersję; podsumowanie zastąpienia i przypięcia |
| **Pobieranie** | Stara → nowa wersja, pobrane bajty, postęp, etapy: pobieranie / sprawdzanie / instalowanie, błąd lub oczekiwanie na zamknięcie gry | Wstrzymaj, wznów, anuluj; ponów po błędzie |
| **Ustawienia** | Automatyczne aktualizacje, zachowanie po starcie gry, ścieżka instalacji, informacja o zachowaniu zapisów, diagnostyka | Zmień ustawienia, sprawdź integralność |

Ekran pierwszej instalacji to stan „Graj”, nie dodatkowy kreator. Pokazuje docelowe wydanie, miejsce i wymagane wolne miejsce przed przyciskiem `Zainstaluj`. Zmiana folderu instalacji może dojść później; MVP używa katalogu użytkownika bez uprawnień administratora.

Okno zmiany na starszą wersję: **„Zastąpić 0.12.0 wersją 0.11.0?”**. Treść: „Pozostanie jedna zainstalowana wersja. 0.11.0 zostanie przypięta; automatyczna aktualizacja nie przeniesie Cię na nowszą. Zapisy i ustawienia pozostaną.” Akcje: `Wróć` / `Zastąp wersję`. To potwierdzenie zmiany wybranej przez gracza, nie blokada zwykłego auto-update.

Komunikaty mają podawać skutek i następny krok:

- „Brak połączenia. Możesz uruchomić zainstalowaną wersję.”
- „Paczka gotowa. Zamknij grę, aby dokończyć aktualizację.”
- „Plik nie przeszedł weryfikacji. Obecna wersja pozostała bez zmian. Pobierz ponownie.”
- „Za mało miejsca. Zwolnij co najmniej X MiB na dysku instalacji.” Wartość wyliczona z aktualnej paczki i dostępnego miejsca.
- „Wybrane wydanie nie jest już dostępne. Wybierz inne.” Bez cichej instalacji innego buildu.

## 4. GitHub i dystrybucja

**Wdrożone źródło:** publiczne repozytorium `bazylcossac/game`, zgodnie z decyzją właściciela. Gra i launcher mają osobne tagi oraz pliki w tych samych Releases. Poprzednia propozycja osobnego repo z paczkami nie jest już potrzebna. Sam launcher nie zmienia widoczności repozytorium.

Alternatywa dla zamkniętych testów: logowanie każdego uprawnionego użytkownika do GitHub i dostęp do prywatnych Releases. Token wyłącznie w systemowym magazynie poświadczeń, nigdy wspólny PAT zaszyty w aplikacji. Publiczne paczki są prostszą ścieżką dla zwykłego gracza. Odczyt deweloperski wykonany podczas audytu nie stanowi rozwiązania dystrybucji.

Katalog pobiera wszystkie strony Releases, odrzuca drafty, niekompletne assety i niepasujące platformy. Stabilna lista wymaga poprawnego numerowanego tagu, `prerelease=false` i gotowego pliku Windows. Dla produktu „najnowsza stabilna” wybieramy najwyższą zgodną wersję SemVer z tej listy, nie sortowanie tekstowe. Endpoint `/releases/latest` nie obejmuje prerelease, więc nie służy do kanału `najnowsza`. [GitHub Releases API](https://docs.github.com/en/rest/releases/releases).

Identyfikator instalacji: repozytorium + release ID + asset ID + SHA-256 + platforma; dodatkowo wersja i commit, jeżeli dostępne. Ten sam tag testowy lub ten sam numer gry z nowym assetem oznacza inny build. Numerowane wydania powinny stać się niezmienne; podmieniony asset pod tym samym numerem wymaga jawnego komunikatu, nie porównania samych napisów.

Pierwszy backend może mapować obecny `MieczDawida-windows.exe`. Nie wybiera dowolnego `.exe`, archiwum źródeł ani pliku macOS. API assetów dostarcza rozmiar, identyfikator i `digest`; odczytane paczki mają SHA-256. Brak poprawnego digestu lub podpisanego manifestu uniemożliwia auto-instalację, a nie wyłącza weryfikację. [GitHub Release Assets API](https://docs.github.com/en/rest/releases/assets).

Przed pobieraniem utrwalamy tożsamość konkretnego assetu. Nie używamy zmiennego URL `latest/download` jako tożsamości transakcji. Usunięcie lub zmiana `najnowsza` w trakcie pobierania kończy próbę i wymaga odświeżenia katalogu; nie mieszamy fragmentów różnych plików. Przy wznawianiu sprawdzamy asset, ETag/If-Range, Content-Range i końcowy hash; odpowiedź 200 zamiast 206 oznacza rozpoczęcie pliku od zera.

Sprawdzanie: na otwarcie, ręcznie oraz najwyżej co 30 minut przy otwartym launcherze. Cache z ETag, ograniczony retry/backoff, obsługa `Retry-After` i czasu resetu limitu API. Przy błędzie zachowujemy ostatni katalog z oznaczeniem jego wieku; nie blokujemy gry serią ponowień. Nie zakładamy, że anonimowe zapytania warunkowe są bez limitu. [Zalecenia GitHub REST API](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api).

Docelowy manifest `game-release.json` zawiera: `schema_version`, `game_version`, `build_commit`, `channel`, `platform`, `entrypoint`, `asset_id`, `size_bytes`, `sha256`, `minimum_launcher_version`, opcjonalnie `network_protocol_version`. Manifest podpisany osobnym kluczem CI, publiczny klucz w launcherze; SHA-256 z tego samego źródła wykrywa uszkodzenie transferu, ale nie zastępuje niezależnego podpisu wydawcy. Manifest nigdy nie dostarcza dowolnych poleceń shell do wykonania.

## 5. Instalacja i usuwanie starej wersji

Proponowany układ MVP:

```text
%LOCALAPPDATA%/CorpWars/
  launcher/                 aplikacja launchera
  game/
    MieczDawida-windows.exe  jedyna zainstalowana gra; zachowana obecna nazwa pliku
  state/
    installed.json          metadane faktycznie zatwierdzonej instalacji
    preferences.json        kanał / przypięta wersja / auto-update
    transaction.json        dziennik tylko niedokończonej transakcji
  updates/<transaction-id>/
    game.download           jedna nieuruchamialna paczka robocza
  logs/                     ograniczone rozmiarem logi launchera
```

`updates` znajduje się na tym samym woluminie co `game`. Rozszerzenie `.download` i brak rejestracji w katalogu instalacji oddzielają paczkę roboczą od gry. Podczas transferu potrzebne jest miejsce na starą grę i nowy plik: dla obecnych paczek około 372 MiB łącznie, plus launcher i margines roboczy. Po sukcesie pozostaje około 186 MiB gry. Nie obiecujemy aktualizacji bez dodatkowego wolnego miejsca.

Przebieg transakcji:

1. Ustal cel i pobierz blokadę instalacji; drugi proces launchera otwiera pierwsze okno. Sprawdź ścieżki, wolne miejsce i uprawnienia. Żadne czyszczenie nie wychodzi poza własny katalog transakcji.
2. Pobierz do `game.download`. Postęp liczy rzeczywiste bajty. Pauza zachowuje co najwyżej jeden plik częściowy, anulowanie usuwa tylko ten plik. Zmiana celu kończy poprzednią transakcję.
3. Sprawdź rozmiar, SHA-256, format/architekturę EXE i podpis manifestu, gdy wdrożony. Nie uruchamiaj pobranego pliku „dla sprawdzenia”. Błąd przed podmianą pozostawia dotychczasową grę.
4. Poczekaj na zamknięcie gry. Sprawdzenie obejmuje śledzony proces i rzeczywistą dostępność pliku do podmiany, nie tylko nazwę procesu. Zablokuj `Graj` na czas zatwierdzania. Nie zabijaj gry.
5. Zapisz i utrwal dziennik: tożsamość starego i nowego pliku, hashe, ścieżki i faza. Dla pojedynczego EXE zastosuj podmianę na tym samym woluminie, np. `ReplaceFileW` z pustym parametrem backupu; przy pierwszej instalacji przenieś sprawdzony plik do pustego miejsca docelowego. Nie twórz `.old`.
6. Potwierdź stan pliku docelowego, zapisz `installed.json` przez plik tymczasowy i zamianę, usuń zbędne pliki transakcji. Dopiero teraz pokaż nową wersję jako zainstalowaną i odblokuj uruchomienie.

**Obsługa awarii podmiany jest obowiązkowa.** `ReplaceFileW` bez backupu nie gwarantuje zachowania starego pliku przy każdym błędzie; np. 1176 może oznaczać brak starego pliku i pozostawioną paczkę roboczą. Po błędzie lub restarcie sprawdzamy faktyczne pliki i hashe, a nie sam JSON. Jeśli nowy plik jest już poprawnie na miejscu, kończymy zapis metadanych; jeśli został tylko poprawny plik roboczy, próbujemy dokończyć instalację; przy niejednoznacznym/uszkodzonym stanie blokujemy start i proponujemy naprawę. Pozostałości starszego pliku sprzątamy tylko po identyfikacji w zarządzanym katalogu. Nie obiecujemy pełnego rollbacku bez kopii. [Dokumentacja ReplaceFileW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew).

Powrót do poprzedniej wersji to nowe pobranie wybranego wydania i ta sama procedura zastąpienia. Brak lokalnego archiwum oznacza, że powrót wymaga internetu i dostępnego assetu na GitHub. Ta konsekwencja wynika z wymagania jednej kopii.

Zapisów `user://` nie umieszczamy wewnątrz zarządzanej instalacji. Zmiana nazwy projektu Miecz Dawida → Corp Wars wymaga osobnego sprawdzenia rzeczywistych ścieżek i ewentualnej migracji ustawień w grze. Launcher nie kasuje żadnego z tych katalogów ani nie wykonuje automatycznej migracji wstecz przy downgrade.

## 6. Technologia i granice uprawnień

Implementacja: **Tauri 2 + lokalny JavaScript/CSS dla widoków, Rust dla instalacji i pobierania**. Windows używa WebView2; instalator sprawdza dostępność runtime. Wydajność i rozmiar finalnej paczki mierzymy po zbudowaniu, nie wyprowadzamy ich z samego wyboru frameworka. [Wymagania Tauri](https://v2.tauri.app/start/prerequisites/).

Moduły:

- `ReleaseProvider`: GitHub, cache, stronicowanie, identyfikacja paczek; bez decyzji o kasowaniu.
- `VersionPolicy`: kanał stabilny/testowy/przypięcie oraz porównanie docelowej tożsamości z instalacją.
- `DownloadManager`: strumieniowe pobieranie, wznowienia, weryfikacja; bez buforowania całego EXE w RAM.
- `GameInstaller`: blokada, dziennik, podmiana, naprawa po awarii, kontrolowane sprzątanie.
- `GameProcess`: uruchomienie tylko zweryfikowanego lokalnego EXE, wykrycie zakończenia procesu.
- `LauncherUI`: tylko wąskie komendy do backendu i zdarzenia postępu; bez bezpośredniego dostępu do dowolnych plików/shella.

Opisy wydania są niezaufaną treścią: Markdown bez aktywnego HTML/skryptów. Linki otwieramy w przeglądarce systemowej po kliknięciu. Backend weryfikuje hosty HTTPS i przekierowania, nie przekazuje tokenu GitHub do innego hosta. Nazwy assetów nie stają się ścieżkami; brak `..`, ścieżek bezwzględnych, junctionów prowadzących poza katalog zarządzany. W MVP nie rozpakowujemy arbitralnych archiwów.

Updater Tauri służy do **aktualizacji samego launchera**, z jego własnymi podpisami i wersją. Nie zastępuje opisanego instalatora zewnętrznej gry Godot. Aktualizacja launchera nigdy nie zaczyna się w trakcie zatwierdzania gry. [Tauri Updater](https://v2.tauri.app/plugin/updater/).

Po starcie gry launcher domyślnie się minimalizuje i zatrzymuje odświeżanie widoków. Brak usługi działającej stale i brak autostartu z Windows w MVP. Cele do zmierzenia: spoczynkowe CPU poniżej 1% na wskazanym komputerze testowym, brak ciągłych animacji, brak odczytu pełnego EXE przy każdym odmalowaniu. Integralność sprawdzamy po pobraniu, przy naprawie i gdy zmienią się metadane pliku.

## 7. Kolejność wdrożenia i warunki ukończenia

| Etap | Wynik | Warunek ukończenia |
| --- | --- | --- |
| 1. Projekt | Ten dokument i interaktywne widoki | Wybór wersji, zastąpienie, postęp, błąd i offline dają się przejść w makiecie |
| 2. Źródło wydań | Uzgodniona dystrybucja publiczna albo logowanie testerów; adapter obecnych assetów | Zwykła instalacja launchera odczytuje rzeczywisty katalog bez poświadczeń dewelopera |
| 3. Pionowy prototyp Windows | Tauri, instalacja pojedynczego EXE, Graj, katalog wersji | Na czystym profilu pobiera, sprawdza i uruchamia wybrane wydanie; po zmianie zostaje jeden EXE |
| 4. Aktualizacje i awarie | Auto-update, pin, kanał testowy, dziennik i naprawa | Przechodzi scenariusze poniżej, w tym przerwanie w każdej fazie |
| 5. Dystrybucja | Instalator launchera, podpisy, manifest CI, diagnostyka, zgodność serwera | Test na drugim komputerze, z normalnego konta Windows, bez dostępu do repo kodu |

MVP pobiera całe około 195 MB przy każdej zmianie wersji. Aktualizacje różnicowe, macOS, zmiana dysku i archiwum buildów testowych są późniejszymi etapami. Nie są potrzebne do pierwszego działającego launchera, ale nie powinny być reklamowane jako już dostępne.

## 8. Kryteria odbioru instalatora

| Przypadek | Oczekiwany wynik |
| --- | --- |
| Pierwszy start bez gry | Instalacja wybranego wydania; dokładnie jeden docelowy EXE |
| Auto-update 0.11 → 0.12 | Pobranie i weryfikacja przed podmianą; brak 0.11 i paczki tymczasowej po sukcesie |
| Ręczny powrót 0.12 → 0.11 | Zastąpienie, przypięcie 0.11; restart launchera nie podnosi wersji |
| Powrót do „Najnowsza stabilna” | Instalacja najwyższej dostępnej stabilnej wersji i ponowne śledzenie kanału |
| Nowy build pod `najnowsza` | Wykrycie zmiany po tożsamości assetu/hashu mimo tej samej nazwy tagu |
| Gra działa, w tym uruchomiona spoza launchera | Brak podmiany i zabijania procesu; czytelne oczekiwanie |
| Anulowanie, brak sieci, zły hash, brak miejsca przed zatwierdzeniem | Stara instalacja nadal działa; żadnego niezweryfikowanego EXE w miejscu startowym |
| Awaria procesu/zasilania w pobieraniu, weryfikacji, podmianie i zapisie JSON | Odtworzenie stanu z dziennika i plików; naprawa, jeśli stan nie jest pewny |
| Win32 1175/1176/1177, blokada antywirusa, odmowa dostępu | Obsłużony stan plików; brak fałszywego „Gotowe”; ograniczone ponawianie |
| Dwa launchery, restart z częściowym pobraniem, usunięty asset | Jedna transakcja, wznowienie tylko tego samego assetu lub czytelne ponowne pobranie |
| Stare zapisy, nazwa użytkownika z polskimi znakami/spacjami, DPI 200% | Dane zachowane, poprawne ścieżki, dostępne wszystkie akcje |
| Numerowana paczka zmieniona pod tym samym tagiem | Zmiana tożsamości wykryta; brak cichego zastąpienia przypiętego buildu |
| Wydanie bez właściwego assetu/digestu, rate limit, brak dostępu do repo | Brak auto-instalacji; dokładny komunikat; sprawna obecna gra dostępna |
| Usuwanie/naprawa instalacji | Operacje wyłącznie w zarządzanym katalogu; żadnego usuwania zapisów ani innych kopii na dysku |

Pomiary na prawdziwym instalatorze obejmują czas pobrania i podmiany, zajęte miejsce po sprzątaniu, CPU/RAM w spoczynku oraz wpływ uruchomionego launchera na grę. Makieta potwierdza wygląd i przebieg interakcji, nie poprawność operacji dyskowych ani aktualizacji.

## 9. Weryfikacja obecnego projektu

- Poprawna składnia JavaScript i unikalne identyfikatory elementów.
- Render ekranu głównego w motywie jasnym i ciemnym, szerokość 728 px; podgląd mobilny 390 px. Wszystkie cztery ekrany bez poziomego przepełnienia także przy 320 px.
- Sprawdzone w DOM makiety: potwierdzenie downgrade i przypięcie, pauza/wznowienie, odrzucenie błędnego pliku i ponowienie, oczekiwanie na koniec gry, anulowanie, brak miejsca, uruchomienie offline, pierwsza instalacja oraz wybór kanału testowego. Wszystkie asercje przeszły.
- Obejrzane osobno: lista wersji, postęp aktualizacji, ustawienia i okno potwierdzenia na wąskim ekranie. Brak błędów konsoli w podglądach.
- Powyższe sprawdzenia dotyczyły wcześniejszej makiety. Właściwy launcher w `launcher/` ma osobny backend i testy opisane niżej.

## 10. Stan wdrożenia 0.1.0

- Działają: anonimowy katalog GitHub, wybór kanału lub przypięcie paczki, pełne pobranie, SHA-256 i PE x64, pojedynczy EXE, pauza/anulowanie, oczekiwanie na zamknięcie gry, uruchomienie pliku gry, auto-update przy otwartym launcherze i ustawienia.
- Przeszło 9 testów backendu: integralność, filtrowanie wydań, przypięcie tożsamości, blokada instancji, niedokończony transfer, odzyskiwanie przed/po podmianie i zachowanie starej gry przy uszkodzonej paczce.
- Test integracyjny pobrał prawdziwe 0.12.0 i 0.11.0 do tymczasowego katalogu. Potwierdził instalację, zastąpienie starszą wersją, jeden plik gry, brak pliku tymczasowego/dziennika oraz przypięcie po restarcie. Nie uruchamiał meczu multiplayer ani nie zmieniał zapisów gracza.
- Zbudowano instalator NSIS x64 oraz EXE portable. Workflow `.github/workflows/launcher.yml` publikuje oba pliki i sumy kontrolne pod tagiem `launcher-v0.1.0`; pozostawia znacznik latest gry bez zmian.
- Uruchomiono gotowy EXE Windows i sprawdzono natywne okno przez computer-use: prawidłowy katalog z GitHub, lista 0.12.0/0.11.0 i kanału testowego, ekran pierwszej instalacji oraz ustawienia. Widoki komunikują się z rzeczywistym backendem, bez warstwy symulacji makiety.
- Pauza dotyczy bieżącego procesu; po awarii/ponownym otwarciu pobieranie zaczyna się od zera. Wznowienia Range/If-Range pozostają etapem dalszego rozwoju.
- Podpisy manifestów, certyfikat Windows, samodzielny updater launchera, macOS oraz testy wszystkich fizycznych awarii zasilania i blokad systemu pozostają do dalszego wdrożenia. Wersja 0.1.0 bazuje na digestach paczek GitHub i kontroli odzyskiwania z dziennika; nie obiecuje niezależnej weryfikacji wydawcy.
