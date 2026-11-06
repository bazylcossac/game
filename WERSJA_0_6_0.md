# Wersja 0.6.0

Uruchom `graj.bat`. W Szybkiej bitwie wybierz **Wojna czołgów → Dolina Pancerna**.
Mapa ma 1020 × 900 m; wzgórza oddzielają bazy od pola walki. Cele to kamieniołom,
centralna przeprawa i stacja paliw. Starty przeciwnych stron dzieli co najmniej 769 m,
a żadna z testowanych 100 par stanowisk nie ma bezpośredniej linii strzału.

Szturmowiec wybiera w arsenale jeden z dwóch zestawów:

- **3 granaty plazmowe**, rzucane klawiszem G.
- **Wyrzutnia AT-43 z 2 rakietami**, wybierana klawiszem 4. Jedna rakieta jest załadowana,
  druga w zapasie; przeładowanie trwa 2,6 s. Ten zestaw nie ma granatów. Dwa bezpośrednie
  trafienia niszczą czołg z pełnym pancerzem. Pocisk leci 82 m/s i jest liczony przez serwer.

14 nowych korpusów broni, osobny model rakiety oraz części żołnierza przygotowano w Blenderze.
Bronie mają wymodelowane mechanizmy, szyny, wentylację, magazynki i osprzęt.
Celowniki, tłumiki, chwyty i ogniwa nadal zmieniają wygląd oraz parametry broni w warsztacie.
Postacie mają nowe ubrania, hełmy, gogle, buty, rękawice i oporządzenie; zachowują animacje
i model o mniejszej liczbie szczegółów na dużej odległości. Lasery mają krótsze, węższe ślady,
mniejszy rozbłysk i ograniczoną poświatę; rakieta ma korpus, stabilizatory i smugę silnika.

Edytowalne źródła: `art_source/armory.blend`, `art_source/trooper.blend`.
Generator: `tools/blender_armory.py`. Nowe modele są własną geometrią projektu.

Gra nadal zawiera dwa miejsca w czołgu (E – wejście, X – zmiana miejsca), niezależny
karabin dachowy i inżyniera z fortyfikacjami (V – wybór, T – budowa).

Klient i serwer muszą mieć wersję 0.6.0.

Sprawdzone: 30 testów nowych funkcji (także wspólny pancerz dwóch członków załogi),
7 testów rakiet przez rzeczywiste połączenie ENet, 15 testów załogi, 28 inżyniera,
12 kolizji i 25 testów map. Skrócony mecz 12 botów na Dolinie zakończył się zwycięstwem
i 15 eliminacjami, bez wpadania pod ziemię. Testy sterowania, wyposażenia i klikanego
warsztatu 3D zakończyły się bez błędów. Kopia w `giera_wersja_testowa` przeszła ponowny
import modeli i wszystkie 30 testów nowych funkcji.
