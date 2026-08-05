FROM ghcr.io/wayblueorg/hyprland:latest

RUN dnf copr enable -y llamatron/bazaar && \
    dnf copr enable -y chronoscrat/oh-my-posh && \
    dnf install -y --skip-unavailable \
    curl tar fastfetch hyprpaper swww bazaar-store distrobox \
    mangohud gamemode quickshell SwayNotificationCenter oh-my-posh && \
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && \
    dnf clean all

COPY files/etc /etc
COPY scripts/rebrand.sh /tmp/rebrand.sh

RUN bash /tmp/rebrand.sh && \
    find /etc/skel/.config/ -type f -name "*.sh" -exec chmod +x {} + && \
    find /etc/skel/.config/ml4w/scripts/ -type f -exec chmod +x {} + && \
    find /etc/skel/.config/hypr/scripts/ -type f -exec chmod +x {} +

RUN bootc container lint
