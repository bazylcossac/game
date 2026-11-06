# Wersja testowa 0.5.1

Uruchom `graj.bat`, następnie wybierz **SZYBKA BITWA**, tryb i mapę.

- **Neonowa Dzielnica**: nocne miasto, neony, deszcz, estakada i własne tło dźwiękowe.
- **Stacja Rdzeń**: reaktor, magazyny i korytarze, wentylacja i brzęczenie instalacji.
- Obie mapy: Podbój, Klasyczne PvP, Deathmatch oraz Bomba 5v5. Boty grają również offline.
- To mapy piechoty; Podbój ma pięć flag bez czołgów w bazach.
- W Fabryce dodano osłonę rozdzielającą stanowiska bomby.
- Menu zawiera ekran autorów i licencji. Stacja wykorzystuje trzy zmodyfikowane modele
  z Godot TPS Demo (CC BY 3.0), z własnym układem mapy.

Ta paczka nadal używa Godota z `C:\Users\stroj\Godot`; nie jest samodzielnym plikiem EXE.
Osobna kopia do grania: `C:\Users\stroj\Desktop\giera_wersja_testowa`.
Paczka serwera: `paczka_vps/miecz-dawida-serwer.tar.gz`. Klient i serwer wymagają wersji 0.5.1.

Nie obejmuje jeszcze Inżyniera z budowaniem, drugiego miejsca w czołgu ani frakcji Automatów.

Sprawdzenie: import i kompilacja bez błędów, 26 kontroli map, 39 testów wyposażenia,
16 krótkich meczów botów (8 istniejących kombinacji i 8 na nowych mapach),
testy reguł Bomby i czołgów oraz dwa połączenia ENet serwer–klient.
Po poprawce listy odrodzeń ponowiono wszystkie 8 meczów nowych map i testy reguł:
133 kontrole zaliczone, 0 niezaliczonych. Obejrzano zrzuty obu map i menu.
