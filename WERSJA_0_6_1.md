# Wersja 0.6.1

Nowe dźwięki strzałów. Każda broń ma teraz dwie wersje:

- **Twój strzał:** czysty, stereo, z pełnym „piuu”, od wysokiego tonu do niskiego ogona,
  z krótkim uderzeniem na początku i dołem. Słyszysz go tylko ty.
- **Strzał innych:** ten sam dźwięk, ale przytłumiony: mono, bez góry pasma i o 6 dB ciszej.
  Dalej słychać, z której strony pada i jaka to broń.

Dotyczy to wszystkich broni palnych, karabinu i działa czołgu, działek mechów oraz wyrzutni AT-43.
Dźwięki są syntezowane, nie pochodzą z żadnego filmu. Model naśladuje uderzenie młotkiem
w napiętą stalową linę: wysokie częstotliwości docierają pierwsze, a odbicia tworzą ogon.

Generator: `tools/gen_audio_blaster.py`. Parametry każdej broni są w tabeli `SHOTS`,
a przytłumienie ustawiają `muffle` i `WORLD_DROP_DB`.

Klient i serwer muszą mieć wersję 0.6.1.
