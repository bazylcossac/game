# Wersja 0.14.0: nowe postacie

Pierwsze publiczne wydanie od 0.12.0, więc zawiera też całe 0.13.0 (Corp Wars, Rebelia przeciw
Korpo, Corp City, tarcza energetyczna i wychylanie). Szczegóły tamtej wersji: `WERSJA_0_13_0.md`.

## Postacie od nowa

Żołnierze obu stron są zbudowani od zera w Blenderze. Każdy to jedna siatka, która zgina się w
stawach, zamiast zestawu sztywnych brył: koniec z okrągłymi przegubami i wystającymi kwadratami.

- **Korpo** to roboty w czarnych garniturach. Zamiast twarzy mają ciemną stalową czaszkę z daszkiem
  nad wizjerem, skośne czerwone oczy i rząd stalowych zębów. Nic na nich nie świeci poza oczami.
  Krawat każdej klasy powtarza się paskiem przez środek głowy, więc klasę widać też od tyłu.
  Audytor ma celownik nad okiem i maszt sensorów, Dyrektor złotą obręcz i anteny, Serwisant
  moduł naprawczy z zielonym krzyżem, Technik skrzynkę z narzędziami, Headhunter długi płaszcz i
  kapelusz, a Likwidator to garnitur naciągnięty na pancerz, z działem i wyrzutnią zamiast rąk.
- **Rebelia** to ostatni ludzie, ubrani w to, co zostało: kurtki z podwiniętymi rękawami, gołe
  przedramiona, łatane spodnie, owijacze na łydkach, szyte szelki z ładownicami i czerwona opaska.
  Widać ich oczy i twarze, a każda klasa ma inny kolor skóry. Szturmowiec nosi kaptur i czerwoną
  chustę, Sanitariusz czapkę, maseczkę i torbę z krzyżem, Strzelec wyborowy postrzępioną pelerynę,
  Inżynier gogle, respirator, skórzany fartuch i butlę, Dowódca czerwony beret, brodę i radiostację,
  Strzelec ciężki pancerz i hełm wycięte z blachy, a Skoczek skórzaną pilotkę i dwa silniki.
- **Każda klasa ma swoją sylwetkę**: ciężcy są wyraźnie wyżsi i szersi, Szturmowiec drobny,
  snajperzy smukli, Inżynier krępy.

## Wydajność

- Każda postać ma trzy poziomy szczegółów, robione ręcznie, a nie upraszczane automatycznie, więc
  z daleka zachowują kształt. Cała postać to kilka wywołań rysowania, niezależnie od wyposażenia.
- W przeglądarce i na niskiej jakości gra pomija najdokładniejszy poziom.
- Przez lunetę dalecy żołnierze rysują się dokładniejszymi siatkami.

## Poprawki obrazu

- Postacie nie mrugają już w podglądzie klasy w menu (błąd w shaderze dawał migające świecące
  plamy na krawędziach) i nie znikają na granicy poziomów szczegółów kilka metrów od kamery.
- Faktura tkaniny gaśnie z odległości, zamiast mienić się drobną kratką.
