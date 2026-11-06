# Wersja 0.6.2

Nowy, autorski czołg zaprojektowany w Blenderze. Obie strony jeżdżą tą samą maszyną w dwóch
malowaniach: piaskowo-mosiężnym i stalowo-czerwonym.

- **Kadłub:** nisko osadzony klin z długimi bocznymi płozami, które niosą emitery unoszenia
  i kończą się dyszami ciągu. Na płozach są wisząca płyta pancerna, kratki wlotów i butle chłodziwa.
- **Wieża:** płaska, skośna, z odsłoniętą szczeliną działa, tylną półką, koszem na wyposażenie,
  celownikiem, włazem i wyrzutniami dymu.
- **Działo główne:** działo szynowe z dwiema szynami, klamrami i osłoną wylotu.
- **Działko wieżowe:** nowa broń drugiego członka załogi. Stoi na osi wieży i ma własne
  stanowisko z długą lufą.

Działko obraca się teraz o pełne 360° i podnosi niezależnie od wieży. Gdy kierowca obraca działo,
celownik strzelca zostaje w miejscu. Strzelec patrzy znad zamka wzdłuż lufy, pociski wychodzą
z wylotu, a broń odskakuje przy strzale. Puste stanowisko samo wraca nad działo główne.
Zakres pionowy to od −23° do +40°.

Celownik czołgu łapie też żołnierzy, więc oba stanowiska trafiają tam, gdzie wskazują.
Modele kolizji czołgu wydłużono do 7,1 m, żeby pasowały do nowego kadłuba.

Źródło do edycji: `art_source/tank.blend`. Generator: `tools/blender_tank.py`.
Model to własna geometria projektu. Ma ok. 59 tys. trójkątów i uproszczone wersje dla dalszych
odległości. Uszkodzenia, wypalanie i żarzące się szwy wraków działają jak wcześniej.

Klient i serwer muszą mieć wersję 0.6.2.
