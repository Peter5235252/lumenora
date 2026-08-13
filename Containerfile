FROM quay.io/fedora-ostree-desktops/kinoite:44

RUN dnf copr enable -y kylegospo/bazaar && \
    dnf copr enable -y chronoscrat/oh-my-posh && \
    dnf install -y --skip-unavailable \
    curl tar fastfetch pciutils bazaar-store distrobox \
    mangohud gamemode gamescope oh-my-posh eza fish && \
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && \
    dnf clean all

COPY files/etc /etc
COPY files/usr /usr
COPY files/scripts/rebrand.sh /tmp/rebrand.sh

RUN bash /tmp/rebrand.sh && \
    find /etc/skel/.config/ -type f -name "*.sh" -exec chmod +x {} + && \
    systemctl enable lumenora-gpu-detect.service

RUN bootc container lint