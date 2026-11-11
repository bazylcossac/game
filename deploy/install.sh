#!/bin/bash
# Instaluje serwer Corp Wars na VPS z Debianem lub Ubuntu. Uruchom jako root, w folderze
# z paczka: sudo bash install.sh
# Ponowne uruchomienie aktualizuje gre. Twoje ustawienia w /etc/miecz-dawida.env zostaja.
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}.zip"
APP_DIR="/opt/miecz-dawida"
SERVICE_USER="miecz-dawida"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE="${HERE}/miecz-dawida-serwer.tar.gz"

if [ "$(id -u)" -ne 0 ]; then
	echo "Uruchom jako root: sudo bash install.sh" >&2
	exit 1
fi
if [ ! -f "$PACKAGE" ]; then
	echo "Brak pliku $PACKAGE. Skopiuj paczke obok tego skryptu." >&2
	exit 1
fi

echo "== Pakiety systemowe"
apt-get update -qq
apt-get install -y -qq unzip curl libfontconfig1 ca-certificates

echo "== Uzytkownik uslugi"
id "$SERVICE_USER" >/dev/null 2>&1 || useradd --system --home-dir /var/lib/miecz-dawida --create-home --shell /usr/sbin/nologin "$SERVICE_USER"

echo "== Godot ${GODOT_VERSION}"
mkdir -p "$APP_DIR/bin"
if [ ! -x "$APP_DIR/bin/godot" ]; then
	TMP="$(mktemp -d)"
	curl -fsSL -o "$TMP/godot.zip" "$GODOT_URL"
	unzip -q "$TMP/godot.zip" -d "$TMP"
	install -m 755 "$TMP/$GODOT_ZIP" "$APP_DIR/bin/godot"
	rm -rf "$TMP"
fi

echo "== Pliki gry"
systemctl stop miecz-dawida 2>/dev/null || true
rm -rf "$APP_DIR/game"
mkdir -p "$APP_DIR/game"
tar -xzf "$PACKAGE" -C "$APP_DIR/game"
chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/game"

echo "== Import zasobow (przy pierwszym razie moze potrwac kilka minut)"
sudo -u "$SERVICE_USER" HOME=/var/lib/miecz-dawida "$APP_DIR/bin/godot" --headless --path "$APP_DIR/game" --import

echo "== Usluga"
[ -f /etc/miecz-dawida.env ] || install -m 644 "$HERE/miecz-dawida.env" /etc/miecz-dawida.env
install -m 644 "$HERE/miecz-dawida.service" /etc/systemd/system/miecz-dawida.service
systemctl daemon-reload
systemctl enable --now miecz-dawida

# shellcheck disable=SC1091
. /etc/miecz-dawida.env
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
	ufw allow "${PORT}/udp"
fi

sleep 3
systemctl --no-pager --lines=5 status miecz-dawida || true
echo
echo "Gotowe. Serwer dziala na porcie ${PORT} UDP."
echo "Logi:     journalctl -u miecz-dawida -f"
echo "Restart:  systemctl restart miecz-dawida"
echo "Pamietaj, zeby otworzyc port ${PORT} UDP takze w panelu dostawcy VPS."
