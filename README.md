# Miecz Dawida: Laserowy Front

Pierwszoosobowa strzelanka w Godot 4.7. Armia USA walczy o zrujnowane
miasto z armią maszyn Żelaznego Imperium, używając broni laserowej i mieczy
energetycznych. Pięć trybów gry na siedmiu mapach, klasy, boty i gra przez sieć.

## Pobieranie

Gotowe wersje są na stronie **Releases** tego repozytorium. Wydanie `najnowsza` to zawsze ostatni build z gałęzi `main`.

- **Windows:** pobierz `MieczDawida-windows.exe` i uruchom. Przy pierwszym starcie Windows może ostrzec o nieznanym wydawcy: wybierz **Więcej informacji → Uruchom mimo to**.
- **macOS:** pobierz `MieczDawida-macos.zip`, rozpakuj i przenieś aplikację do Programów. Gra nie ma podpisu Apple, więc za pierwszym razem kliknij ją prawym przyciskiem i wybierz **Otwórz**. Jeśli system dalej blokuje start, uruchom w Terminalu `xattr -cr "/Applications/Miecz Dawida.app"`.

Buildy powstają w `.github/workflows/build.yml`. Tag w stylu `v0.10.0` tworzy osobne wydanie.

## Uruchamianie

| Plik | Co robi |
| --- | --- |
| `graj.bat` | Uruchamia grę |
| `serwer.bat` | Serwer dedykowany bez grafiki, port 7777 (UDP) |
| `edytor.bat` | Otwiera projekt w edytorze Godota |

Godot leży w `C:\Users\stroj\Godot`. Jeśli go przeniesiesz, zmień ścieżkę w plikach `.bat`.

Wersja 0.9.0 buduje Neonową Dzielnicę od nowa jako duże miasto 520 × 700 m z szerokimi alejami
dla czołgów i mechów oraz zmienia balans: czołg pada po 6 rakietach, granaty go ranią, a strzały
z broni ręcznej ledwo drapią. Szczegóły: `WERSJA_0_9_0.md`.

Wersja 0.12.0 dodaje panel admina pod F1, strefy bezpieczne wokół baz, niszczenie pustych czołgów,
wsiadanie trwające 2 s, szybkie cięcie pod F i nowy celownik. Szczegóły: `WERSJA_0_12_0.md`.

Wersja 0.11.0 ma listę serwerów z pingiem, serwer bez botów, wybór drużyny po dołączeniu, ping w tabeli pod Tab
i odrodzenie z menu pod Esc. Szczegóły: `WERSJA_0_11_0.md`.

Wersja 0.8.0 ma nowe menu z kartami trybów, map i stron oraz język angielski. Zastępuje Rzeszę grywalnym Żelaznym Imperium, dodaje wybór strony, nowe roboty
i broń Imperium, granaty dymne i zapalające oraz samotną obsługę działka w czołgu.
Szczegóły: `WERSJA_0_8_0.md`.

Wersja 0.7.0 dodaje oddziały z dowódcą, artylerię i punkt odrodzenia oraz nowe modele broni,
modyfikacji i żołnierzy z Blendera. Szczegóły: `WERSJA_0_7_0.md`.

Wersja 0.6.2 wprowadza autorski czołg z Blendera i działko wieżowe drugiego członka załogi,
które obraca się niezależnie od wieży. Szczegóły: `WERSJA_0_6_2.md`.

Wersja 0.6.1 daje każdej broni dwa dźwięki: czysty dla strzelca i przytłumiony dla pozostałych
graczy. Szczegóły: `WERSJA_0_6_1.md`.

Wersja 0.6.0 dodaje Dolinę Pancerną (1020 × 900 m), wyposażenie szturmowca do wyboru:
3 granaty albo wyrzutnię z 2 rakietami, modele broni i żołnierzy przygotowane w Blenderze
oraz mniejsze, czytelniejsze efekty pocisków. Szczegóły: `WERSJA_0_6_0.md`.
Czołg ma dwa niezależne stanowiska i fizyczny kadłub, a inżynier buduje fortyfikacje.

## Sterowanie

| Klawisz | Akcja |
| --- | --- |
| WSAD, mysz | Ruch i rozglądanie |
| LPM | Strzał lub cięcie mieczem |
| PPM | Celowanie, a z mieczem blok, który odbija lasery |
| Shift / Spacja / Ctrl lub C | Sprint / skok / kucanie |
| R | Przeładowanie |
| 1, 2, 3 | Broń główna, pistolet, miecz (w mechu 1 działo, 2 granatnik) |
| 4 | Wyrzutnia przeciwpancerna, jeśli szturmowiec wybrał zestaw rakiet |
| F | Szybkie cięcie mieczem, potem powrót do broni |
| G | Granat plazmowy (mech nie ma granatów) |
| B | Wybór superklasy, gdy masz monetę |
| E | Wsiadanie do czołgu lub transportera i wysiadanie (2 s, drugie E przerywa) |
| M | Duża mapa pola bitwy |
| Z | Czołganie: padnij i wstań (wstajesz też spacją, Shiftem albo C) |
| Y | Dowódca: artyleria |
| X | Zmiana miejsca w czołgu, także z miejsca pasażera na wolne stanowisko |
| N | Termowizja albo widok normalny: w celowniku wyrzutni, u kierowcy i strzelca czołgu |
| V / T | Inżynier: wybór fortyfikacji / rozpoczęcie budowy |
| Tab / Esc | Wyniki / menu |
| F1 | Panel admina do testów |

## Tryby gry

Tryb wybierasz w Szybkiej bitwie albo przy zakładaniu serwera. Wolne miejsca zawsze zajmują
boty, więc w każdy tryb zagrasz sam. Kto dołącza do cudzego serwera, dostaje tryb i mapę od niego.

| Tryb | Id | Mapy | Zasady |
| --- | --- | --- | --- |
| **Podbój** | `podboj` | Neonowa Dzielnica, Ziemia Niczyja, Stare Miasto, Stacja Rdzeń | 5 flag, 350 ticketów, tryb domyślny |
| **Klasyczne PvP** | `pvp` | Neonowa Dzielnica, Ziemia Niczyja, Rynek, Pole Bitwy, Stacja Rdzeń | Dwie drużyny, do 10 na stronę, pierwsza z 75 eliminacjami wygrywa |
| **Deathmatch** | `deathmatch` | Rynek, Neonowa Dzielnica, Stacja Rdzeń | Każdy na każdego, do 16 osób, pierwszy z 30 eliminacjami wygrywa |
| **Wojna czołgów** | `czolgi` | Dolina Pancerna, Ziemia Niczyja, Neonowa Dzielnica | Wszyscy w czołgach, do 6 na stronę, 3 flagi, 150 ticketów |

**Neonowa Dzielnica** (`neonowa_dzielnica`): noc, deszcz, 520 × 700 m szerokich alej, wieżowców i neonów.
**Stacja Rdzeń** (`stacja_rdzen`): hala reaktora, boczne korytarze i magazyny.
To zwarte mapy piechoty; w Podboju mają pięć flag, bez czołgów w bazach.
Obie mają własne tło dźwiękowe oraz odrodzenia drużynowe i Deathmatchu.
Boty walczą na poziomie ulicy/pokładu. Nowe mapy wybierzesz przez **Szybka bitwa → Tryb gry → Mapa**.
Stacja ma nowy układ, z trzema modelami z Godot TPS Demo (CC BY 3.0); nie jest kopią jego całego poziomu.

Stronę wybierasz w menu: USA albo Żelazne Imperium. Boty uzupełniają obie drużyny.
W Deathmatchu nie ma stron, więc wszyscy mają barwy USA.

**Podbój:** drużyna traci ticket za każdą śmierć. Trzymanie 3 flag odbiera wrogowi ticket co
6 s, a 4 lub więcej flag co 2,5 s. Bitwa kończy się, gdy któraś strona spadnie do zera.

**Wojna czołgów:** zasady Podboju, ale każdy wchodzi do walki w czołgu i nie może wysiąść.
Trzymanie 2 flag z 3 odbiera wrogowi ticket co 6 s, a wszystkich 3 co 2,5 s.
Dolina Pancerna ma 1020 × 900 m, rozdzielone wzgórzami bazy, kamieniołom, przeprawę
i stację paliw. Najbliższe przeciwne stanowiska startowe dzieli ponad 760 m;
grzbiety zasłaniają wszystkie bezpośrednie linie strzału między nimi.

Monety i superklasy są w Podboju, PvP i Deathmatchu. Liczby trybów zmienisz w
`scripts/core/modes.gd`.

## Mapy

| Mapa | Id | Opis |
| --- | --- | --- |
| **Stare Miasto** | `stare_miasto` | Zrujnowane miasto: ratusz, dworzec, rynek, fabryka, koszary |
| **Pole Bitwy** | `pole_bitwy` | Otwarte pola, wzgórza, dwie linie okopów, leje po bombach, folwark i młyn |
| **Rynek** | `rynek` | Ciasny plac, dwa pierścienie kamienic i zaułki między nimi |
| **Ziemia Niczyja** | `ziemia_niczyja` | Front 720 × 600 m w błocie i burzy: okopy, zasieki, leje, ruiny kościoła |

Mapę opisuje klasa w `scripts/map/`. Wspólne klocki leżą w `map_kit.gd`, a nowa mapa to podklasa
`MapKit`, która mówi, gdzie co stoi, plus wpis w `scripts/core/modes.gd`.

## Klasy

| | USA | Żelazne Imperium |
| --- | --- | --- |
| 1 | **Szturmowiec**: karabinek, miecz oraz 3 granaty albo 3 rakiety AT | **Droid liniowy**: karabin szturmowy, czerwony miecz świetlny |
| 2 | **Sanitariusz**: leczy sojuszników w promieniu 9 m | **Droid strzelec**: karabin promieniowy |
| 3 | **Strzelec wyborowy**: karabin promieniowy | **Droid ciężki**: działko plazmowe |
| 4 | **Inżynier**: strzelba, miecz i budowanie fortyfikacji | **Droid komando**: rozpylacz wiązki, granaty i ogień |
| 6 | **Strzelec ciężki**: minigun, 135 zdrowia, wolny | **Droid inżynier**: budowanie fortyfikacji |
| Mech | **Atlas**: 480 zdrowia, działo i granatnik (9 granatów) | **Goliat**: 430 zdrowia, bliźniacze działa i granatnik (9 granatów) |
| Super | **Ranger**: plecak odrzutowy i miecz | **Widmo**: maskowanie optyczne |

Obie strony są grywalne, także przeciw botom.

## Mapy

| Mapa | Tryby | Charakter |
| --- | --- | --- |
| Stare Miasto | Podbój | Zrujnowane miasto 548 × 454 m, ulice po 26 m z osłonami dla piechoty, czołgi i mechy |
| Dolina Pancerna | Wojna czołgów | 1020 × 900 m o zachodzie słońca, zagajniki, skały, osłonięte bazy i trzy cele |
| Pole Bitwy | Klasyczne PvP | Wzgórza, okopy, leje po bombach, pył w powietrzu |
| Ziemia Niczyja | Podbój, Klasyczne PvP, Wojna czołgów | Burza nad frontem: dwie linie okopów na stronę, zasieki, flary, pioruny |
| Rynek | Deathmatch, Klasyczne PvP | Plac pod wieżą zegarową, barykady, bombowce nad głową |
| Neonowa Dzielnica | Deathmatch, Klasyczne PvP, Podbój, Wojna czołgów | Deszczowa noc, śródmieście 520 × 700 m, szerokie aleje, wieżowce, kolej nad bulwarem |
| Stacja Rdzeń | Deathmatch, Klasyczne PvP, Podbój | Reaktor z galerią, kriogenika, labirynt kontenerów |

Boty chodzą po ziemi, więc dachy i galerie są wyższym poziomem tylko dla graczy. Na Stacji
mech mieści się jedynie w części pomieszczeń.

## Uzbrojenie, perki i poziomy

Przed każdym wejściem do walki wybierasz wyposażenie na ekranie rozmieszczenia. Podgląd
postaci pokazuje klasę z założonymi dodatkami, a postać obrócisz, przeciągając myszą.

- **Bronie:** każda klasa ma 3 lub 4 bronie główne i wspólne 3 boczne.
- **Szturmowiec:** w arsenale wybierz 3 granaty (G) albo wyrzutnię AT-43 (4),
  z jedną rakietą w lufie i dwiema w zapasie. Rakieta leci 82 m/s; sześć bezpośrednich
  trafień niszczy pełny pancerz czołgu. Zestaw AT nie ma granatów.
- **Dodatki:** 4 miejsca, czyli celownik, wylot lufy, chwyt i ogniwo. Pistolety mają tylko
  wylot i ogniwo. Dodatki zmieniają obrażenia, zasięg, magazynek, przeładowanie, celność
  i odrzut. Zielony słupek to poprawa względem broni bazowej, czerwony to pogorszenie.
- **Odrzut:** każda broń kopie inaczej. Karabin szturmowy ściąga w lewo, działko w prawo
  i coraz mocniej w górę, a pistolety maszynowe rozbiegają się na boki. Po serii lufa wraca.
- **Perki:** 2 miejsca, ciało i sprzęt. Nie działają w superklasach ani w czołgach.
- **Poziomy:** 30 poziomów. Punkty z walki to XP, wygrana runda daje 500, przegrana 150.
  Zakładka Postępy pokazuje, co odblokujesz na kolejnych poziomach.

Postępy trzyma ten, kto prowadzi grę. W grze lokalnej to Twój komputer, a na VPS serwer, więc
na serwerze zaczynasz od poziomu 1. Serwer sam sprawdza każde wyposażenie, więc zablokowanej
broni nie da się zdobyć podmianą plików. Gracza rozpoznaje losowy klucz zapisany w jego
ustawieniach. Bez tego pliku gracz startuje od nowa. Klucz leci przez sieć bez szyfrowania,
więc chroni przed przypadkiem, a nie przed kimś, kto podsłuchuje ruch.

## Monety i superklasy

Co 80 do 130 sekund w losowym, osiągalnym miejscu pojawia się złota moneta (najwyżej 2 na
mapie, po 2 minutach znika). Widać ją jako słup światła i znacznik. Bierze ją pierwszy, kto
dobiegnie, także bot. Klawisz **B** otwiera wybór, a 1 lub 2 zamienia Cię w superklasę na miejscu.

Żeby nie były za mocne:

- działają 75 s (mech) lub 90 s (pozostałe), a potem wracasz do swojej klasy z 60% zdrowia,
- nie regenerują się i nie działa na nie leczenie,
- mech jest wolny, nie skacze, nie wejdzie do budynków, nie można się w niego zamienić
  w ciasnym miejscu, a miecze ranią go o 50% mocniej,
- plecak Rangera ma paliwo na 3,5 s lotu, a Widmo odsłania się po strzale lub trafieniu,
- zginiesz z niewykorzystaną monetą, to wypada na ziemię i wróg może ją zabrać.

Tempo monet i siłę klas zmienisz w `scripts/core/c.gd`.

## Czołgi

Każda strona ma w bazie 2 czołgi antygrawitacyjne: **Patriot** (USA) i **Wilk** (Imperium).
Podejdź i wciśnij **E**. W/S to napęd, A/D skręca kadłub, mysz obraca wieżę niezależnie od
kadłuba. Slot 1 to działo laserowe z wybuchem obszarowym, slot 2 to karabin wieżowy.
Czołg ma 4 miejsca. Kierowca prowadzi i strzela z działa, a gdy jedzie sam, pod klawiszem 2 ma też działko.
Drugie miejsce to strzelec działka na dachu: jego celowanie jest niezależne. Kierowca i strzelec patrzą z
pierwszej osoby. Pozostałe dwa miejsca to pasażerowie, którzy widzą czołg z trzeciej osoby.
X przenosi na wolne stanowisko, także z miejsca pasażera.

- Czołg ma 800 punktów pancerza i zostaje tam, gdzie z niego wysiądziesz, razem z uszkodzeniami.
- Broń piechoty prawie nie rusza pancerza (2%). Czołg niszczy 6 rakiet, a granaty zadają 40% obrażeń.
- Zniszczony czołg eliminuje całą załogę i po 60 s wraca do bazy (w Wojnie czołgów nowy pojazd dostajesz przy odrodzeniu).
- Czołg nie wjedzie do budynków, ale do flagi Fabryka w Starym Mieście podjedzie przez wybite ściany hali.
- Transporter nie ma działa. Mieści kierowcę i 6 żołnierzy, ma 650 punktów pancerza.
- Boty wsiadają dopiero do czołgu, który stoi wolny dłużej niż 25 s, więc masz pierwszeństwo.

## Inżynier

V wybiera worki, drut, zaporę przeciwpancerną albo działko, T rozpoczyna budowę przy
własnej fladze. Budowanie trwa i zużywa materiały. Fortyfikacje blokują ruch oraz trasy
botów, można je niszczyć, a podgląd pokazuje, gdzie konstrukcja może stanąć.

## Modele w Blenderze

Broń i modyfikacje powstają w `tools/blender_weapons.py`, żołnierze w `tools/blender_trooper.py`,
a czołg w `tools/blender_tank.py`. Edytowalne pliki są w `art_source/`.
Godot korzysta z eksportów GLB w `assets/models/armory`. Nowe korpusy broni zachowują
widoczne celowniki, końcówki lufy, chwyty i wymienne ogniwa oraz dotychczasowe animacje.
Z bliska postacie mają nowe ubrania, hełmy, gogle, rękawice i oporządzenie; z daleka
silnik przełącza je na tańszy model. Pliki źródłowe nie są importowane podczas gry.

## Założenia treści

- Przeciwnikiem jest fikcyjne Żelazne Imperium: armia maszyn z własnym znakiem i nazwami.
  W grze nie ma III Rzeszy ani jej symboli.
- Roboty, broń i znaki to własne projekty, inspirowane klimatem, bez kopiowania cudzych marek.
- Bojownicy to żołnierze w hełmach i goglach, bez karykatur.

## Serwer na VPS

Serwer to ten sam projekt uruchomiony bez grafiki. Trafienia, zdrowie, flagi, monety i czołgi
liczy serwer. Grają na nim sami gracze, bez botów. Dołącza się w Gra sieciowa: lista serwerów
pokazuje tryb, mapę, graczy i ping, a drużynę wybiera się po dołączeniu. Listę trzyma `C.SERVERS`.
Lista pyta serwer o dane na tym samym porcie co gra, więc nie trzeba otwierać nic więcej.

Instalacja na Debianie lub Ubuntu (64-bit x86):

1. Na Windowsie uruchom `spakuj_serwer.bat`. Powstanie folder `paczka_vps`.
2. Skopiuj go na VPS: `scp -r paczka_vps root@ADRES_VPS:/root/`
3. Na VPS: `cd /root/paczka_vps && sudo bash install.sh`
4. Otwórz port **7777 UDP** w panelu dostawcy VPS. Skrypt otwiera go tylko w `ufw`.
5. Wpisz adres VPS do `C.SERVERS` w `scripts/core/c.gd`. W grze: Gra sieciowa, Dołącz.

Skrypt pobiera Godota, instaluje usługę, która startuje z systemem i wraca po awarii.
Tryb, mapę, nazwę i port ustawisz w `/etc/miecz-dawida.env`. Postępy graczy leżą
w katalogu domowym usługi (`/var/lib/miecz-dawida`), więc aktualizacja gry ich nie kasuje.

Serwer przyjmuje `--mode=` i `--map=` z identyfikatorami z tabel powyżej, także w `serwer.bat`.
Puste `--map=` oznacza domyślną mapę trybu. `--limit=` skraca mecz: to tickety, eliminacje albo
wygrane rundy, zależnie od trybu. `--name=` to nazwa na liście serwerów. Domyślnie serwer nie ma
botów. `--bots=` je włącza: to liczebność strony, a w Deathmatchu wszystkich.
Pusty serwer czeka: mecz stoi, a po wyjściu ostatniego gracza zaczyna się od nowa.
Tryby z limitem miejsc odrzucają kolejnych graczy komunikatem o pełnym serwerze.
Jeśli `/etc/miecz-dawida.env` pochodzi ze starszej wersji, dopisz do niego `MODE=` i `MAP=`.

```
journalctl -u miecz-dawida -f      logi na żywo
systemctl restart miecz-dawida     restart po zmianie ustawień
```

Aktualizacja gry: spakuj ponownie, skopiuj i uruchom `install.sh`. Przy zmianie `C.VERSION`
gracze muszą mieć tę samą wersję co serwer, inaczej zostaną odrzuceni.

## Struktura

```
scripts/core      stałe, tabele broni i klas, tryby gry, materiały
scripts/autoload  ustawienia, dźwięk, sieć
scripts/map       klocki map, siedem map, siatka nawigacji
scripts/game      świat, serwer meczu, żołnierz, boty, gracz, broń, efekty
scripts/game/modes  zasady trybów: flagi i tickety, eliminacje
scripts/ui        HUD, menu, ekrany, mapa taktyczna
scripts/dev       testy automatyczne
shaders           niebo, teren, lasery, flagi, hologramy
tools             generatory tekstur, dźwięków (Python: numpy, pillow) i modeli (Blender),
                  modele powstają w blender_tank.py, blender_weapons.py i blender_trooper.py,
                  strzały są w gen_audio_blaster.py, reszta walki w gen_audio_battle.py,
                  a burza w gen_audio_storm.py
```

Balans broni i klas jest w `scripts/core/c.gd`, a dodatki, perki i poziomy w `scripts/core/gear.gd`. Dźwięk i część grafiki
powstają ze skryptów w `tools/`. Tekstury, sprite'y i fonty od innych autorów są spisane
ze źródłem i licencją w `assets/LICENSES.md`.

## Testy

Argumenty podaje się po `--`:

```
godot --headless -- --test=sim --seconds=60        mapa, osiągalność flag i monet, mecz botów
godot -- --test=input --windowed                   sterowanie, runda, menu (okno przejmuje fokus)
godot -- --test=screens --windowed --out=KATALOG   zrzuty ekranu
godot -- --test=supers --windowed --out=KATALOG    zrzuty klas, mechów i monet
godot -- --test=anims --windowed --out=KATALOG     animacje klatka po klatce, strzały, trafienia
godot -- --test=machines --windowed --out=KATALOG  mechy i czołgi na pustej scenie, bez meczu
godot -- --test=bench --windowed --out=KATALOG     warsztat broni 3D, sterowany prawdziwymi kliknięciami
godot --headless -- --test=map-audit --map=rynek    osłony, odsłonięty teren i linie strzału jednej mapy
godot --headless -- --test=gear --progress-file=PLIK  wyposażenie, odrzut, perki, poziomy
godot -- --test=deploy --windowed --out=KATALOG    zrzuty ekranu rozmieszczenia i dodatków
godot --headless -- --test=client --port=7792      klient sieciowy do serwera testowego
godot --headless -- --test=modes                  mecze botów i reguły wszystkich trybów
godot --headless -- --test=modes --only=mapy       osiągalność celów, monet i odrodzeń
godot --headless -- --test=tank-collision          kolizje czołgów, kierowca, obrót i odrodzenie
godot --headless -- --test=combat-upgrade          osłony baz, trasy czołgów, zestawy AT i nowe modele
godot --headless -- --test=crew                    załoga dwuosobowa
godot --headless -- --test=engineer                budowanie fortyfikacji
godot --headless -- --test=ordnance-net --ordnance-role=server  testowy serwer AT na porcie 17862
godot --headless -- --test=ordnance-net --ordnance-role=client  testowy klient AT, uruchom po serwerze
godot -- --test=modes-shots --only=nowe --out=KATALOG  zrzuty dwóch map sci-fi
python tools/test_arenas_network.py              lokalny serwer i klient obu nowych map
godot --headless -- --test=fixes                  wsiadanie, amunicja, puste czołgi, strefy, stamina, F, panel admina
godot -- --test=perf-weather --windowed --map=neonowa_dzielnica  koszt klatki z pogodą i bez
godot --headless -- --test=respawn                odrodzenie z menu, także w pojazdach
godot --headless -- --test=browser-net --port=17870  lista, drużyna, ping i odrodzenie; najpierw uruchom --server --port=17870 --mode=podboj --map=stare_miasto --name=Testowy
godot -- --test=browser-shots --windowed --port=17870 --out=KATALOG  zrzuty listy, wyboru drużyny, tabeli i menu
```
