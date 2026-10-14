case ":${XDG_CONFIG_DIRS:-}:" in
    *:/usr/share/kernora/xdg:*) ;;
    *) export XDG_CONFIG_DIRS="/usr/share/kernora/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}" ;;
esac
