# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2020-present Fewtarius

PKG_NAME="jelos"
PKG_VERSION="$(date +%Y%m%d)"
PKG_ARCH="any"
PKG_LICENSE="apache2"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_SHORTDESC="JELOS Meta Package"
PKG_LONGDESC="JELOS Meta Package"
PKG_IS_ADDON="no"
PKG_AUTORECONF="no"
PKG_TOOLCHAIN="make"

if [ ! "${OPENGL}" = "no" ]; then
  PKG_DEPENDS_TARGET+=" ${OPENGL} glu libglvnd"
fi

if [ "${OPENGLES_SUPPORT}" = yes ]; then
  PKG_DEPENDS_TARGET+=" ${OPENGLES}"
fi

PKG_BASEOS="plymouth-lite grep wget libjpeg-turbo util-linux xmlstarlet bluetool gnupg gzip patchelf \
            imagemagick terminus-font vim bash pyudev dialog six git dbus-python coreutils miniupnpc \
            nss-mdns avahi alsa-ucm-conf MC fbgrab modules system-utils"

PKG_UI="emulationstation es-themes"

PKG_SOFTWARE=""

PKG_COMPAT=""

PKG_TOOLS="i2c-tools rclone jslisten evtest tailscale"

### Tools for mainline devices
case "${DEVICE}" in
  handheld|RG552)
    PKG_TOOLS+=" mesa-demos"
  ;;
esac

PKG_MULTIMEDIA="ffmpeg mpv vlc"

PKG_EXPERIMENTAL=""

### Project specific variables
case "${PROJECT}" in
  Rockchip)
    PKG_EMUS+=" retropie-shaders"
    PKG_COMPAT+=" lib32"
  ;;
  PC)
    PKG_BASEOS+=" installer"
  ;;
esac

if [ ! -z "${BASE_ONLY}" ]
then
  PKG_DEPENDS_TARGET+=" ${PKG_BASEOS} ${PKG_TOOLS} ${PKG_UI}"
else
  PKG_DEPENDS_TARGET+=" ${PKG_BASEOS} ${PKG_TOOLS} ${PKG_UI} ${PKG_COMPAT} ${PKG_MULTIMEDIA} ${PKG_SOFTWARE} ${PKG_EXPERIMENTAL}"
fi

make_target() {
  :
}

makeinstall_target() {

  mkdir -p ${INSTALL}/usr/config/
  rsync -av ${PKG_DIR}/config/* ${INSTALL}/usr/config/
  ln -sf /storage/.config/system ${INSTALL}/system
  find ${INSTALL}/usr/config/system/ -type f -exec chmod o+x {} \;

  mkdir -p ${INSTALL}/usr/bin/

  ## Compatibility links for ports
  ln -s /storage/roms ${INSTALL}/roms
  ln -sf /storage/roms/opt ${INSTALL}/opt

  ### Add some quality of life customizations for hardworking devs.
  if [ -n "${JELOS_SSH_KEYS_FILE}" ]; then
    mkdir -p ${INSTALL}/usr/config/ssh
    cp ${JELOS_SSH_KEYS_FILE} ${INSTALL}/usr/config/ssh/authorized_keys
  fi

  if [ -n "${JELOS_WIFI_SSID}" ]; then
    sed -i "s#wifi.enabled=0#wifi.enabled=1#g" ${INSTALL}/usr/config/system/configs/system.cfg
    cat <<EOF >> ${INSTALL}/usr/config/system/configs/system.cfg
wifi.ssid=${JELOS_WIFI_SSID}
wifi.key=${JELOS_WIFI_KEY}
EOF
  fi
}

post_install() {
  ln -sf jelos.target ${INSTALL}/usr/lib/systemd/system/default.target

  mkdir -p ${INSTALL}/etc/profile.d
  cp ${PROJECT_DIR}/${PROJECT}/devices/${DEVICE}/device.config ${INSTALL}/etc/profile.d/01-deviceconfig

  # Split this up into other packages
  cp ${PKG_DIR}/sources/autostart/autostart ${INSTALL}/usr/bin
  mkdir -p ${INSTALL}/usr/lib/autostart/common
  mkdir -p ${INSTALL}/usr/lib/autostart/daemons
  cp ${PKG_DIR}/sources/autostart/common/* ${INSTALL}/usr/lib/autostart/common
  cp ${PKG_DIR}/sources/autostart/daemons/* ${INSTALL}/usr/lib/autostart/daemons
  if [ -d "${PKG_DIR}/sources/autostart/${DEVICE}" ]
  then
    mkdir -p ${INSTALL}/usr/lib/autostart/${DEVICE}
    cp ${PKG_DIR}/sources/autostart/${DEVICE}/* ${INSTALL}/usr/lib/autostart/${DEVICE}
  fi
  chmod -R 0755 ${INSTALL}/usr/lib/autostart ${INSTALL}/usr/bin/autostart
  enable_service jelos-autostart.service

  if [ ! -d "${INSTALL}/usr/share" ]
  then
    mkdir "${INSTALL}/usr/share"
  fi
  cp ${PKG_DIR}/sources/post-update ${INSTALL}/usr/share
  chmod 755 ${INSTALL}/usr/share/post-update

  # Issue banner
  cp ${PKG_DIR}/sources/issue ${INSTALL}/etc
  ln -s /etc/issue ${INSTALL}/etc/motd
  cat <<EOF >> ${INSTALL}/etc/issue
==> Build Date: ${BUILD_DATE}
==> Version: ${OS_VERSION}

EOF

  cp ${PKG_DIR}/sources/scripts/* ${INSTALL}/usr/bin
  enable_service jelos-automount.service

  if [ -d "${PKG_DIR}/sources/asound/${DEVICE}" ]
  then
    cp ${PKG_DIR}/sources/asound/${DEVICE}/* ${INSTALL}/usr/config/
  fi

  sed -i "s#@DEVICENAME@#${DEVICE}#g" ${INSTALL}/usr/config/system/configs/system.cfg

  if [[ "${DEVICE}" =~ RG351P ]]
  then
    sed -i "s#.integerscale=1#.integerscale=0#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#.rgascale=0#.rgascale=1#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#audio.volume=.*\$#audio.volume=100#g" ${INSTALL}/usr/config/system/configs/system.cfg
  fi

  if [[ "${DEVICE}" =~ RG503 ]] || [[ "${DEVICE}" =~ RG353P ]] || [[ "${DEVICE}" =~ handheld ]]
  then
    sed -i "s#.integerscale=1#.integerscale=0#g" ${INSTALL}/usr/config/system/configs/system.cfg
  fi

  if [[ "${DEVICE}" =~ handheld ]]
  then
    sed -i "s#fstrim.enabled=0#fstrim.enabled=1#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#3do.cpugovernor=performance#3do.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#arcade.cpugovernor=performance#arcade.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#atarijaguar.cpugovernor=performance#atarijaguar.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#atomiswave.cpugovernor=performance#atomiswave.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#dreamcast.cpugovernor=performance#dreamcast.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#j2me.cpugovernor=performance#j2me.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#mame.cpugovernor=performance#mame.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#n64.cpugovernor=performance#n64.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#naomi.cpugovernor=performance#naomi.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#nds.cpugovernor=performance#nds.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#pcfx.cpugovernor=performance#pcfx.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#pc.cpugovernor=performance#pc.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#psp.cpugovernor=performance#psp.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#pspminis.cpugovernor=performance#pspminis.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
    sed -i "s#virtualboy.cpugovernor=performance#virtualboy.cpugovernor=interactive#g" ${INSTALL}/usr/config/system/configs/system.cfg
  fi

  ### Defaults for non-main builds.
  BUILD_BRANCH="$(git branch --show-current)"
  if [[ ! "${BUILD_BRANCH}" =~ main ]]
  then
    sed -i "s#ssh.enabled=0#ssh.enabled=1#g" ${INSTALL}/usr/config/system/configs/system.cfg
  fi

}
