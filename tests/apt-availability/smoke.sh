#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 0755 /usr/sbin/policy-rc.d
mkdir -p /etc/apt/sources.list.d
rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list
cp /build/old-debian.sources /etc/apt/sources.list.d/debian.sources
printf 'Acquire::Languages "none";\nAPT::Install-Recommends "false";\n' > /etc/apt/apt.conf.d/99kernora-smoke
apt-get update
apt-get install -y --no-remove /build/archive-old.deb
printf 'INITIAL_FOREIGN_ARCHITECTURES=%s\n' "$(dpkg --print-foreign-architectures)"
[[ -z "$(dpkg --print-foreign-architectures)" ]]
if apt-get -s install steam-installer > /build/steam-before.log 2>&1; then
    cat /build/steam-before.log
    exit 1
fi
cat /build/steam-before.log
grep -Eq 'Unable to locate package steam-installer|Package .steam-installer. has no installation candidate' /build/steam-before.log
printf 'BASELINE_STEAM_UNAVAILABLE\n'
/usr/libexec/kernora-update-channel set demo
dpkg -i /build/archive-new.deb
dpkg --print-foreign-architectures | grep -Fxq i386
grep -Fxq 'Architectures: amd64' /etc/apt/sources.list.d/kernora-demo.sources
apt-get update 2>&1 | tee /build/apt-after.log
if grep -Eq '^W:|^E:|Skipping.*i386' /build/apt-after.log; then exit 1; fi
apt-get -s install steam-installer | tee /build/steam-plan.log
if grep -q '^Remv ' /build/steam-plan.log; then exit 1; fi
apt-get install -y --no-remove steam-installer
dpkg-query -W -f='${Package} ${Architecture} ${Status}\n' steam-installer steam-libs-i386 libc6:i386
[[ "$(dpkg-query -W -f='${Status}' steam-installer)" == 'install ok installed' ]]
[[ "$(dpkg-query -W -f='${Status}' steam-libs-i386)" == 'install ok installed' ]]
printf 'UPGRADED_STEAM_INSTALLED\n'
if apt-cache policy proton-vpn-gtk-app | grep -q 'Candidate:'; then exit 1; fi
apt-get install -y --no-remove /build/proton-release.deb
apt-get update
apt-cache policy proton-vpn-gtk-app proton-vpn-gnome-desktop | tee /build/proton-policy.log
grep -Fq 'repo.protonvpn.com' /build/proton-policy.log
apt-get -s --no-remove install proton-vpn-gnome-desktop | tee /build/proton-plan.log
if grep -q '^Remv ' /build/proton-plan.log; then exit 1; fi
printf 'PROTON_OFFICIAL_SOURCE_RESOLVES\n'
printf 'APT_AVAILABILITY_SMOKE_OK\n'
