# Wersja 0.11.0

## Lista serwerów

Gra sieciowa ma teraz listę serwerów. Pokazuje nazwę, tryb, mapę, liczbę graczy i ping, a dołącza
się jednym przyciskiem. Lista sama się odświeża co kilka sekund. Serwer niedostępny, pełny albo z
inną wersją gry ma wyszarzony przycisk i napis z powodem.

Lista pyta serwer na tym samym porcie co gra (7777 UDP), więc na VPS nie trzeba otwierać niczego
nowego. Serwery są wpisane w `C.SERVERS` w `scripts/core/c.gd`. Nadal można dołączyć po adresie.

## Serwer bez botów

Serwer dedykowany to teraz sami gracze. Pusty serwer czeka, a gdy wyjdzie ostatni gracz, mecz
zaczyna się od nowa. `--bots=12 --difficulty=1` włącza boty z powrotem, ale usługa na VPS ich już
nie przekazuje. Serwer przyjmuje też `--name=`, czyli nazwę na liście (`NAME=` w
`/etc/miecz-dawida.env`). Szybka bitwa i serwer zakładany z menu mają boty jak dotąd.

## Wybór drużyny

Po dołączeniu do serwera wybierasz drużynę na ekranie z liczbą graczy po każdej stronie i dopiero
wtedy wczytuje się mapa. W Deathmatchu nie ma stron, więc tego ekranu nie ma.

## Ping

Tabela pod Tab ma w grze sieciowej kolumnę PING. Serwer mierzy każdego gracza co 2 sekundy. Zaraz
po wczytaniu mapy wartość jest zawyżona i przez około 10 sekund spada do prawdziwej.

## Odrodzenie

W menu pod Esc jest ODRÓDŹ SIĘ. Giniesz, po zwykłym czasie odrodzenia wybierasz klasę i wracasz.
Liczy się to jak śmierć: dolicza zgon, w Podboju zabiera ticket, a nikt nie dostaje eliminacji.
Z pojazdu najpierw wysiadasz, więc czołg i reszta załogi zostają cali.

## Zgodność

Sposób łączenia się zmienił, więc 0.10.0 i 0.11.0 nie zagrają ze sobą. Serwer i wszyscy gracze
potrzebują nowej wersji. Nowa gra pokaże przy starym serwerze napis o starszej wersji.
