# Wybrana wersja na VPS

Panel `https://giera-panel.vercel.app` → **Wersje i wdrożenia** → **Synchronizuj GitHub**
→ **Wdróż** przy wybranej wersji. Wdrożenie może zlecić tylko właściciel.
Starszą wersję wybiera się tak samo. Push do `main` nie aktualizuje już VPS.

`deploy-server.yml` potrzebuje istniejących sekretów repozytorium: `VPS_HOST`,
`VPS_SSH_KEY`, `VPS_KNOWN_HOSTS`, `CI_TOKEN`. Token panelu wymaga Actions read/write
i Contents read. Token wbudowany workflow ma Contents write do publikacji paczki.

Panel rozpoznaje tag do konkretnego SHA i rezerwuje jedno wdrożenie. Workflow
potwierdza ten sam SHA; narzędzia wdrożenia pochodzą z rewizji workflow, a źródła gry
z osobnego checkoutu wybranej wersji. Nie wykonuje instalatorów z wybranego wydania
z uprawnieniami root. Klienci Windows i macOS nie są ponownie eksportowani.

Źródła serwera są pakowane do `CorpWars-server-linux.tar.gz`, razem z manifestem
wersji; SHA256 i manifest są także dodawane do wydania GitHub. Import na VPS działa
jako użytkownik gry, przed zatrzymaniem obecnej instancji. Godot musi mieć wersję 4.7.2.

Instalator pod osobną usługą systemd sprawdza hash i zawartość archiwum, importuje,
przełącza symlink `game` na `/opt/miecz-dawida/releases/DEPLOYMENT_ID`, restartuje
`miecz-dawida` i pyta grę przez ENet (bez dołączania gracza). Sprawdza też katalog
procesu i wersję odpowiedzi. Nieudany start przywraca poprzedni katalog i restartuje grę.
Pierwsze przełączenie zachowuje dotychczasowy katalog pod nazwą `legacy-DEPLOYMENT_ID`.

Konfiguracja `/etc/miecz-dawida.env` i dane `/var/lib/miecz-dawida` nie są nadpisywane.
Nie usuwamy starych wydań automatycznie. Zgodność przyszłych zmian formatu zapisów
trzeba zapewniać w samej grze; rollback kodu nie cofa migracji danych.

Brak odpowiedzi SSH nie oznacza niepowodzenia instalacji. Usługa może nadal działać.
W panelu wynik `unknown` blokuje następny deploy. Sprawdź
`systemctl status giera-deploy-DEPLOYMENT_ID` i `/root/miecz-deploy/DEPLOYMENT_ID/result.json`.
Gdy istnieje wynik, ponowienie **tego samego runu** w GitHubie odczytuje go bez ponownej
instalacji i ponawia callback. `started.json` bez wyniku i bez działającego instalatora
wymaga ręcznego sprawdzenia, nie powtarzaj przełączenia w ciemno.

Testy: `python3 -m unittest discover -s deploy -p test_release.py -v`.
Obejmują tożsamość wydania, deterministyczną paczkę, hash, traversal/symlinki,
przełączenie i rollback z zachowaniem danych.
