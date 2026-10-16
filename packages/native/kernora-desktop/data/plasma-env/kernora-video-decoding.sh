if [ -d "${KERNORA_SYSFS:-/sys}/module/nvidia" ]; then
    (
        state="${XDG_STATE_HOME:-$HOME/.local/state}/kernora/vlc-decoding"
        for entry in "debian:${XDG_CONFIG_HOME:-$HOME/.config}/vlc/vlcrc" "flatpak:$HOME/.var/app/org.videolan.VLC/config/vlc/vlcrc"; do
            name=${entry%%:*}
            rc=${entry#*:}
            [ -e "$state/$name" ] && continue
            if ! grep -q '^avcodec-hw=' "$rc" 2>/dev/null; then
                mkdir -p "${rc%/*}" && printf '\navcodec-hw=none\n' >> "$rc" || continue
            fi
            mkdir -p "$state" && : > "$state/$name"
        done
    ) 2>/dev/null
fi
