# Wersja 0.7.0

## Oddziały

Oddziały działają w trybach Podbój i Klasyczne PvP. Na ekranie rozmieszczenia, w zakładce
**ODDZIAŁ**, tworzysz oddział albo dołączasz do istniejącego. W oddziale jest do 4 graczy.
Twórca zostaje dowódcą. Gdy dowódca wyjdzie, dowodzenie przejmuje najstarszy stażem członek.

**Dowódca oddziału** to osobna klasa, 110 HP. Dowódca nie może jej zmienić, a nikt inny jej nie
wybierze. Domyślnie ma karabinek laserowy, do wyboru też karabin szturmowy i krótki karabinek,
a poza tym pistolet, miecz, jeden granat, lornetkę i radiostację.

### Artyleria (klawisz Z)

Z unosi lornetkę, lewy przycisk wzywa ostrzał, prawy anuluje.

- **Ładowanie:** pełne w 150 s dla samego dowódcy, o 25% szybciej za każdego kolejnego członka.
  Zabójstwo członka oddziału daje 8%, zdobyta flaga 15%.
- **Przerwy:** pierwszy ostrzał najwcześniej po 60 s, kolejne co najmniej co 75 s.
- **Cel:** od 20 do 280 m, w polu widzenia, pod otwartym niebem. Pod dachem i w strefie 55 m
  od bazy wroga ostrzał jest niemożliwy.
- **Ostrzeżenie:** wszyscy, także wrogowie, widzą czerwony krąg i słyszą gwizd przez 6 s.
- **Ostrzał:** 6 pocisków co 0,6 s w promieniu 12 m. Pocisk zadaje do 90 obrażeń w promieniu 6 m,
  czołgom połowę. Sojusznicy są bezpieczni. Ostrzał niszczy też fortyfikacje i punkty odrodzenia.

### Punkt odrodzenia (klawisz T)

Oddział ma jeden punkt, 150 HP. Dowódca stawia go na ziemi. Ponowne T przenosi go na nowe miejsce.

- **Gdzie:** co najmniej 60 m od bazy wroga, 22 m od flagi, której nie trzymacie, i bez wroga
  w promieniu 12 m.
- **Odrodzenie:** członkowie wybierają przycisk **PUNKT ODDZIAŁU** obok DO BOJU. Kolejne wejście
  możliwe po 10 s. Wróg w promieniu 12 m blokuje punkt.
- **Zniszczenie:** punkt można zestrzelić lub wysadzić, boty też do niego strzelają.
  Niszczący dostaje 40 punktów, a oddział czeka 45 s na nowy punkt.

## Nowe modele z Blendera

- **Broń:** 14 broni palnych, każda z osobnego projektu, z prawdziwymi otworami, szynami, mechanizmami
  i wytarciem krawędzi. Rękojeści trzech mieczy i pocisk AT też są nowe.
- **Modyfikacje:** kolimator, celownik holograficzny, luneta, kompensator, tłumik, stabilizator
  i chwyty mają nowe modele w tych samych punktach mocowania.
- **Żołnierze:** mundury z fałdami, kamizelki z ładownicami, hełmy z maskami, buty, rękawice,
  ochraniacze i osobny hełm Rzeszy. Sprzęt każdej klasy i ręce z widoku pierwszej osoby są nowe.
- **Dowódca i punkt odrodzenia:** radiostacja z anteną, naramienniki, oznaczenie na hełmie,
  celownik przy oku oraz trójnóg z masztem.

Żadne gotowe modele nie pasowały: darmowe paki były niskopoligonowe, stare lub bez szkieletu,
a realistyczne płatne. Wszystko jest własną geometrią projektu.

Generatory: `tools/blender_weapons.py`, `tools/blender_trooper.py`, wspólna biblioteka
`tools/blender_kit.py`. Źródła do edycji: `art_source/weapons.blend`, `art_source/trooper.blend`.

Klient i serwer muszą mieć wersję 0.7.0.
