# Wersja 0.12.0

## Pojazdy

- **Wsiadanie i wysiadanie trwa 2 sekundy.** Pod celownikiem pojawia się pasek. Drugie E przerywa.
  Odejście od pojazdu na więcej niż 2 m też przerywa wsiadanie.
- **Pusty czołg da się zniszczyć.** Strzały, granaty, pociski czołgów i rakiety ranią pojazd, w którym
  nikt nie siedzi. Własna drużyna go nie uszkodzi. Za zniszczenie jest 40 punktów, a wrak zostaje na
  miejscu i wraca po zwykłym czasie odrodzenia pojazdu.
- **Wysiadanie nie uzupełnia już amunicji.** Piechota wychodzi z tymi magazynkami i granatami, z
  którymi wsiadła. Czołg też pamięta, ile zostało w działku i karabinie, dla kierowcy i dla strzelca
  osobno. Pełną amunicję daje dopiero nowy pojazd, po zniszczeniu albo w nowej rundzie.

## Strefa bezpieczna

W trybach z flagami (Podbój, Wojna czołgów) każda strona ma strefę bezpieczną wokół bazy. Kto stoi w
swojej strefie, żołnierz czy pojazd, nie odnosi obrażeń. Strefa obejmuje parking czołgów strony:
promień to od 32 do 62 m, zależnie od mapy. Na mapie i minimapie widać ją jako kółko w kolorze
strony, a w strefie pojawia się napis. Wróg wchodzący do cudzej strefy nie jest chroniony.

## Walka

- **F tnie raz i wraca do broni.** Szybkie cięcie wyjmuje miecz, uderza i chowa go. Kto sam wybrał
  miecz klawiszem 3, zostaje przy mieczu.
- **Sprint po wyczerpaniu staminy.** Przy zerowej staminie nie da się biegać, dopóki nie wróci 30%.
  Postać nie szarpie już na każdym okruchu staminy. Pasek staminy świeci wtedy na czerwono.
- **Nowy celownik.** Cztery kreski mają większą przerwę w środku i ciemny obrys, a na środku jest
  kropka. Widać, w co się celuje.

## Mapa i menu

- Duża mapa pod M pokazuje, w którą stronę patrzysz: strzałka i stożek widzenia.
- Ekran rozmieszczenia pokazuje zdrowie każdej klasy (z perkiem Twardziel, jeśli go masz).
- Ustawienia mają przełącznik „Deszcz i efekty pogody”.

## Panel admina (F1)

Na razie dostępny dla wszystkich, do testów rozgrywki. Każde polecenie zapisuje się w logu serwera.

- Gracz: nieśmiertelność, noclip (Spacja w górę, Ctrl w dół, Shift szybciej), nieskończona amunicja
  i granaty, zdrowie i amunicja, teleport w miejsce pod celownikiem, moneta na superklasę.
- Boty: +2 i -2 na stronę, manekin wroga przed tobą (stoi i nie strzela), zabij lub usuń wszystkie
  boty, zamroź boty.
- Pojazdy: czołg lub transporter przed tobą, odnów wszystkie pojazdy.
- Mecz: zajmij wszystkie flagi, wygraj rundę, nowa runda.

Włączone tryby testowe widać nad paskiem zdrowia.

## Wydajność pogody

Nowy test `--test=perf-weather` mierzy klatkę z pogodą, bez deszczu i pyłu oraz bez całej pogody,
z kilku stałych miejsc. Na komputerze, na którym powstała ta wersja (1920 × 1080, najwyższa jakość),
deszcz kosztował zwykle 0,05–0,15 ms na klatkę, czyli 1–5% FPS. W jednym miejscu na Ziemi Niczyjej
wyszło 0,6 ms. Na słabszej karcie różnica może być większa; wtedy pomoże przełącznik w ustawieniach.

## Zgodność

Doszły nowe polecenia sieciowe, więc serwer i gracze potrzebują wersji 0.12.0.
