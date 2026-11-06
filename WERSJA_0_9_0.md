# Wersja 0.9.0

## Neonowa Dzielnica od nowa

Stara mapa 112 × 140 m zniknęła. Nowa ma **520 × 700 m** i wygląda jak amerykańskie śródmieście
nocą w deszczu.

- **Siatka ulic:** bulwar szeroki na 64 m, dwie aleje po 48 m i cztery przecznice po 44 m.
- **Wieżowce:** do około 260 m, w czterech typach: płyty, uskoki, bliźniacze wieże i okrągłe wieże.
  Na dole sklepy, neony i ekrany reklamowe.
- **Nad bulwarem** biegnie kolej na podporach, wyżej latają pojazdy i drony.
- **Plac w centrum** z holograficzną fontanną i czterema budynkami, przez które da się przejść.
- **Park i budowa** przerywają siatkę i dają otwarte miejsca do walki.
- **Osłony na ulicach:** barierki, autobusy, kontenery, wraki i zaparkowane auta.
- **Czołgi są teraz na tej mapie:** 4 na stronę w Podboju, 6 w Wojnie czołgów.

**Miejsce dla czołgów i mechów jest zmierzone.** `--test=neon` tnie każdą ulicę co 4 m. Najwęższy
przejazd ma 14 m dla czołgu i 18 m dla mecha, a obie maszyny dojeżdżają do każdej flagi z obu baz.

Mapa jest cała otwarta we wszystkich trybach. PvP i Deathmatch zaczynają bliżej środka,
145 m od placu zamiast 315 m, żeby na początku rundy nie iść minuty. Mapę można teraz wybrać także
w Wojnie czołgów, a w Podboju jest pierwsza na liście.

## Balans czołgów

Czołg nadal ma 800 punktów. Tak je teraz traci:

| Czym | Obrażenia | Ile trzeba na pełny czołg |
| --- | --- | --- |
| Rakieta AT | 150 | **6** |
| Granat odłamkowy tuż przy kadłubie | do 50 | około 16 |
| Działo czołgu | 90 | 9 |
| Działo mecha | 6–7,5 na strzał | ponad 100 |
| Działko wieżowe | 0,6 na strzał | ponad 1300 |
| Karabinek laserowy | 0,42 na strzał | około 1900, czyli 60 magazynków |
| Miecz | 5% zwykłych obrażeń | bardzo dużo |

- **Szturmowiec z wyrzutnią ma teraz 3 rakiety**, żeby dwie osoby mogły zniszczyć czołg.
  Wcześniej miał 2, co przy nowych liczbach znaczyłoby trzech graczy.
- **Boty obu stron** noszą wyrzutnie i strzelają nimi do czołgów. Wcześniej robił to tylko Ruch Oporu.
- Rakieta dalej zadaje piechocie 110 obrażeń przy trafieniu, a mech dostaje tyle samo co piechota.

## Modele na ulicach

Proste bryły zastąpiły modele z Blendera (`tools/blender_city.py`, 23 rodzaje):

- **Pojazdy:** sedan, auto sportowe, furgonetka i autobus na poduszkach, z oświetleniem i ośmioma
  kolorami lakieru.
- **Zieleń:** dwa gatunki drzew, palmy wzdłuż bulwaru i donice z krzewami. Drzewa stoją przy ulicach,
  na pasie środkowym i w parku.
- **Ulica:** latarnie, sygnalizacja na każdym skrzyżowaniu, kioski, wiaty, bariery, kontenery i
  kontenery na śmieci.
- **Bitwa:** spalone auta, ciężarówki i czołgi, martwe drzewa, jeże przeciwczołgowe i stare latarnie.
  Korzystają z nich też Stare Miasto, Pole Bitwy i Rynek.

Kolizje zostały w niewidocznych bryłach, więc serwer nie potrzebuje modeli.

## Stare Miasto

- **Ulice mają 26 m zamiast 10 m**, a mapa urosła do 548 × 454 m.
- **Wraki i barykady stoją przy krawężnikach**, środek ulicy zostaje wolny.
- **Doszły** chodniki, krawężniki, tory tramwajowe, martwe drzewa i spalone auta.
- **Hala fabryki ma wybite ściany.** Wcześniej czołg nie mógł podjechać do flagi Fabryka.
- Najwęższy przejazd ma 8 m dla czołgu i 10 m dla mecha.
