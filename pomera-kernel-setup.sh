#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 yasoteien
# pomera-kernel を FDTP なしで入れる台本。中身を読んでから、root で流す（curl | sh はしない）。
# Set up the pomera-kernel apt source and install the kernel without FDTP. Read it first, then run it as root.
#
#   sudo sh pomera-kernel-setup.sh [install] [--yes]   公開鍵（指紋を確かめる）と apt の置き場を足し、pomera-kernel を入れる
#                                                     （始めに FDTP の案内と免責を出して聞く。端末でない時と --yes の時は聞かずに進む。
#                                                      --yes は免責に同意した事になる）
#   sudo sh pomera-kernel-setup.sh source      公開鍵と apt の置き場だけを足す（入れない）
#   sudo sh pomera-kernel-setup.sh remove      公開鍵と apt の置き場を消す（入れたカーネルは消さない）
#   sh pomera-kernel-setup.sh status           公開鍵か apt の置き場があれば 0
#
# POMERA_KERNEL_APT_URL で置き場の URL を替えられる（既定 https://yasoteien.github.io/pomera-kernel-apt/）。
# 公開鍵は、この台本の隣の pomera-kernel.asc があればそれを、無ければ置き場から取る。
set -eu
FPR=E9B307FAF435923A22E2A7109110B3116ECA5467
# 受け入れる機種（kernel/deb/machine.sh と同じ。DM250 の日本版だけ）
OK_MODEL="King Jim Pomera DM250"
OK_COMPAT="kingjim,pomera-dm250 rockchip,rk3128"
URL=${POMERA_KERNEL_APT_URL:-https://yasoteien.github.io/pomera-kernel-apt/}
case $URL in */) ;; *) URL=$URL/ ;; esac
KEY=/usr/share/keyrings/pomera-kernel.asc
SOURCE=/etc/apt/sources.list.d/pomera-kernel.sources
mode=install; yes=0
for a in "$@"; do case $a in --yes|-y) yes=1 ;; *) mode=$a ;; esac; done
say() { printf '%s\n' "$1"; [ -z "${2:-}" ] || printf '%s\n' "$2"; }
die() { say "$1" "$2" >&2; exit 1; }

case $mode in
status) [ -e "$KEY" ] || [ -e "$SOURCE" ]; exit $? ;;
install|source|remove) ;;
*) sed -n '7,12p' "$0" >&2; exit 2 ;;
esac
[ "$(id -u)" = 0 ] || die "root で流してください（sudo sh $0 $mode）。" "Run it as root (sudo sh $0 $mode)."
if [ "$mode" = remove ]; then
	rm -f "$KEY" "$SOURCE"
	say "公開鍵と apt の置き場を消しました（入れたカーネルはそのままです。戻すなら sudo pomera-kernel rollback）。" \
		"Removed the public key and the apt source (the installed kernel stays; to go back: sudo pomera-kernel rollback)."
	exit 0
fi

if [ "$mode" = install ]; then
	say "FDTP（https://github.com/yasoteien/fdtp）の ./configure（.deb 版なら sudo fdtp-pomera-setup）からも pomera-kernel を入れられます。" \
		"pomera-kernel can also be installed from FDTP's ./configure (sudo fdtp-pomera-setup for the .deb version; https://github.com/yasoteien/fdtp)."
	say "その方が、Wi-Fi・内蔵メモリ（ポメラの文書を Linux から読み書き）・PD ハブでの充電・時計のずれの直し・HEIC の写真の表示などの設定も一緒にでき、カーネルを替えた後に要らなくなった設定の片付けもしてくれます。" \
		"That way Wi-Fi, the internal memory (Pomera documents from Linux), PD hub charging, the clock drift fix, HEIC photo viewing and more are set up too, and settings no longer needed after the kernel change are cleaned up."
	say "" ""
	say "【免責】試験版です。無保証で、使うのは自己責任です。ポメラの本体・SD カード・データに不具合や損失が起きても、私たち（yasoteien）は責任を負いません。キングジム、および ichinomoto 氏が ekesete.net（https://www.ekesete.net/log/?p=9565）で公開されている DM250 用 Debian 13 イメージ（以下「イメージ」）とは関係のない、非公式の物です。入れる前に SD カードの写しを取ってください。戻すには sudo pomera-kernel rollback、起動しなくなったら SD カードを抜けば純正のソフトで起動します。" \
		"[Disclaimer] Test release: no warranty, use at your own risk. We (yasoteien) are not responsible for any fault or loss of the Pomera, the SD card or data. Unofficial, with nothing to do with King Jim or with the DM250 Debian 13 image published by ichinomoto at ekesete.net (https://www.ekesete.net/log/?p=9565) ("the image" below). Copy the SD card before installing. To go back: sudo pomera-kernel rollback; if it no longer starts, take out the SD card and the Pomera starts its own software."
	# 問いは端末の時だけ（--yes は同意した事になる。端末でない時は、上の文を出して進む）
	if [ "$yes" = 0 ] && [ -t 0 ]; then
		printf '%s ' "上の事に同意して、このまま単品で入れますか / Agree to the above and install pomera-kernel alone now? [y/N]"
		read -r ans || ans=
		case $ans in y|Y|yes|YES|はい) ;; *) say "入れませんでした。FDTP: https://github.com/yasoteien/fdtp" "Nothing was installed. FDTP: https://github.com/yasoteien/fdtp"; exit 0 ;; esac
	fi
fi

model=$( { tr -d '\000' < /proc/device-tree/model; } 2>/dev/null || true)
compat=$( { tr '\000' ' ' < /proc/device-tree/compatible; } 2>/dev/null | sed 's/ $//' || true)
[ "$model" = "$OK_MODEL" ] && [ "$compat" = "$OK_COMPAT" ] ||
	die "この機械には入れられません（保証できるのは King Jim Pomera DM250 の日本版だけ。model: ${model:-?}）。" \
		"This machine is not supported (only the Japanese King Jim Pomera DM250; model: ${model:-?})."
[ "$(findmnt -n -o SOURCE / 2>/dev/null)" = /dev/mmcblk1p2 ] ||
	die "SD カードの Debian から起動していません（/ が /dev/mmcblk1p2 でない）。" "Not booted from the Debian on the SD card (/ is not /dev/mmcblk1p2)."
command -v gpg >/dev/null 2>&1 || die "公開鍵の指紋を確かめるには gpg が要ります（sudo apt install gpg）。" \
	"Checking the key fingerprint needs gpg (sudo apt install gpg)."

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
here=$(cd "$(dirname "$0")" && pwd)
if [ -f "$here/pomera-kernel.asc" ]; then
	cp "$here/pomera-kernel.asc" "$tmp/key.asc"
elif command -v curl >/dev/null 2>&1; then
	curl -fsSL "${URL}pomera-kernel.asc" -o "$tmp/key.asc" || die "公開鍵を取れません: ${URL}pomera-kernel.asc" "Cannot fetch the public key: ${URL}pomera-kernel.asc"
else
	wget -q -O "$tmp/key.asc" "${URL}pomera-kernel.asc" || die "公開鍵を取れません: ${URL}pomera-kernel.asc" "Cannot fetch the public key: ${URL}pomera-kernel.asc"
fi
# 自分の鍵束を使わず、空の一時の家で読むだけ（取り込まない）
mkdir -m 700 "$tmp/gpg"
got=$(gpg --batch --no-options --homedir "$tmp/gpg" --with-colons --show-keys "$tmp/key.asc" 2>/dev/null |
	awk -F: '$1 == "pub" { p = 1; next } $1 == "fpr" && p { print $10; p = 0 }')
[ "$got" = "$FPR" ] || die "公開鍵の指紋が違います（${got:-読めない}）。何も設定しません。" "The key fingerprint does not match (${got:-unreadable}); nothing was set up."
say "公開鍵の指紋を確かめました: E9B3 07FA F435 923A 22E2 A710 9110 B311 6ECA 5467" \
	"Key fingerprint checked: E9B3 07FA F435 923A 22E2 A710 9110 B311 6ECA 5467"

install -d "$(dirname "$KEY")" "$(dirname "$SOURCE")"
install -m 0644 "$tmp/key.asc" "$KEY"
cat > "$SOURCE" <<EOF
Types: deb
URIs: $URL
Suites: stable
Components: main
Architectures: armhf
Signed-By: $KEY
EOF
chmod 0644 "$SOURCE"
say "apt の置き場を足しました: $SOURCE" "Added the apt source: $SOURCE"
[ "$mode" = install ] || exit 0

before=$(dpkg-query -W -f='${Version}' pomera-kernel 2>/dev/null || true)
apt-get update
apt-get install -y pomera-kernel
after=$(dpkg-query -W -f='${Version}' pomera-kernel 2>/dev/null || true)
if [ -n "$before" ] && [ "$before" = "$after" ]; then
	say "pomera-kernel はもう最新（$after）です。新しく試すカーネルはありません。" \
		"pomera-kernel is already the newest ($after): there is no new kernel to try."
	exit 0
fi
say "" ""
say "再起動すると、次の順で進みます。" "After the reboot:"
say "  1. まず、今のカーネル（初めて入れる時は、イメージのカーネル）で起動します。" "  1. The Pomera first starts with the current kernel (on the first install, the image's kernel)."
say "  2. ログインの画面が一度出ますが、ログインせずに 1 分ほど待ってください。画面が流れ出して pomera-kernel（試験版）が起動し、もう一度ログインの画面が出ます（最初の画面でログインしても、切り替わる時に切れます）。" \
	"  2. A login prompt appears once; do not log in, wait about a minute. The screen scrolls as pomera-kernel (test release) starts, and the login prompt appears again (a login at the first prompt is cut off by the switch)."
say "  3. 正常に起動すれば、約 2 分後に自動で確定し、U-Boot も書き換えます。以後はカーネルと U-Boot の組で起動します。" \
	"  3. If it starts normally, it is confirmed by itself about 2 minutes later and U-Boot is rewritten too; from then on the Pomera starts with the kernel and U-Boot as a set."
say "  4. うまく起動しなければ、約 5 分以内に自動で今のカーネルに戻ります（U-Boot は書き換えません）。" \
	"  4. If it does not start properly, the Pomera goes back to the current kernel by itself within about 5 minutes (U-Boot is not rewritten)."
say "  5. 確定した後で戻すには: sudo pomera-kernel rollback（次の起動から、1 つ前の組。カーネルと U-Boot が組で戻ります）" \
	"  5. To go back after it is confirmed: sudo pomera-kernel rollback (the previous set from the next boot; kernel and U-Boot go back together)"
say "以後の更新は sudo apt update && sudo apt upgrade です（apt-get なら dist-upgrade）。" \
	"Later updates: sudo apt update && sudo apt upgrade (with apt-get, dist-upgrade)."
say "再起動してください（sudo reboot）。" "Please reboot (sudo reboot)."
