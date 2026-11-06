# Wersja 0.8.0

## Żelazne Imperium zamiast Rzeszy

III Rzesza zniknęła z gry razem z jej znakami, sztandarami, pismem gotyckim i nazwiskami.
Przeciwnikiem jest teraz fikcyjne **Żelazne Imperium**, armia maszyn z własnym znakiem
(zębaty pierścień z rozciętym okiem) i numerami seryjnymi zamiast imion.

**Stronę wybierasz w menu:** w Szybkiej bitwie i w Grze sieciowej. Boty uzupełniają obie drużyny.
Klasy, oddziały, artyleria, czołgi i modyfikacje działają po obu stronach.
W Deathmatchu nie ma stron.

### Roboty

Każda klasa Imperium ma własny model z Blendera:

- **Droid liniowy, strzelec i dowódca:** smukły szkielet z siłownikami, odsłoniętymi kablami
  i kilkoma przykręconymi płytami. Niska głowa z trzema obiektywami.
- **Droid ciężki:** o 13% wyższa, pancerna konstrukcja z reaktorem na plecach i głową
  schowaną między barkami.
- **Droid komando i Widmo:** gładka, ciemna skorupa z rozciętym wizjerem.

Roboty mają metalowe dłonie w widoku pierwszej osoby i własne dźwięki trafień.

### Broń Imperium

14 osobnych modeli broni: szkieletowe korpusy, żebrowane lufy, widełkowe emitery i czerwone ogniwa.
Statystyki i punkty mocowania modyfikacji są takie same jak u Ruchu Oporu, a zestawy broni
dobrano do klas Imperium.

## Nowe menu

- **Ekran główny:** duże pozycje z krótkim opisem, emblematy obu stron i przełącznik języka.
- **Wybór bitwy na jednym ekranie:** karty trybów i map ze scenami z gry, karty stron z emblematami,
  liczba żołnierzy, poziom przeciwnika i podsumowanie obok przycisku startu.
- **Gra sieciowa i serwer:** te same karty. Zakładanie serwera ma ten sam ekran co Szybka bitwa.
- Obrazki kart powstają w prawdziwych mapach: `--test=menu-art`, potem `tools/menu_art.py`.

## Język angielski

- **Przełącznik PL / EN** jest na ekranie głównym i w Ustawieniach. Wybór zostaje zapisany.
- Po angielsku są menu, HUD, ekran rozmieszczenia, uzbrojenie, perki, tryby, mapy, klasy, broń,
  komunikaty i ekran końca gry.
- Serwer wysyła wzór komunikatu, a tekst składa gra gracza. Dzięki temu gracze na jednym serwerze
  mogą mieć różne języki.
- Tytuł po angielsku to **Sword of David: Laser Front**.
- Napisy na ścianach map, takie jak HOTEL czy ARKADA, są częścią map i się nie zmieniają.
- `--test=lang` sprawdza tłumaczenia, kody formatowania i ekrany.

## Granaty

- **Podczas przeładowania nie można rzucać.** Zasadę sprawdza też serwer.
- **Trzy rodzaje:** odłamkowy, dymny i zapalający. **G** rzuca, **H** zmienia rodzaj.
- **Dymny:** chmura na 15 s o promieniu 6,5 m. Zasłania widok, także botom.
- **Zapalający:** wybucha przy uderzeniu i pali przez 8 s, 30 obrażeń na sekundę w promieniu 4,5 m,
  czołgi dostają 15%. Sojusznicy i rzucający są bezpieczni.
- **Nowe modele i animacja rzutu:** wyjęcie zawleczki, zamach, rzut i odskok łyżki.

| Klasa | Odłamkowe | Dymne | Zapalające |
| --- | --- | --- | --- |
| Szturmowiec | 3 (albo 2 rakiety AT) | 1 | 0 |
| Sanitariusz | 1 | 2 | 0 |
| Strzelec wyborowy | 1 | 1 | 0 |
| Inżynier | 1 | 0 | 2 |
| Dowódca oddziału | 1 | 2 | 0 |
| Droid liniowy | 2 (albo 2 rakiety AT) | 1 | 1 |
| Droid strzelec | 1 | 1 | 0 |
| Droid ciężki | 2 | 0 | 1 |
| Droid komando | 3 | 0 | 2 |
| Droid dowódca | 1 | 2 | 0 |

## Czołg

Gdy kierowca jest sam, klawisz **2** przełącza go na działko: główne działo blokuje się w miejscu,
a mysz steruje działkiem. Klawisz **1** wraca na działo i wieża obraca się do celownika.
Jeśli na działku siedzi strzelec, kierowca zostaje przy dziale głównym.

Generatory: `tools/blender_droids.py`, `tools/blender_weapons.py`, `tools/gen_emblems.py`.
Klient i serwer muszą mieć wersję 0.8.0.
