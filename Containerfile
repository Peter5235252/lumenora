FROM ghcr.io/wayblueorg/hyprland:43

RUN dnf copr enable -y llamatron/bazaar && \
    dnf copr enable -y chronoscrat/oh-my-posh && \
    dnf install -y --skip-unavailable \
    fastfetch swww bazaar distrobox \
    mangohud SwayNotificationCenter oh-my-posh && \
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && \
    dnf clean all

COPY files/etc /etc

RUN sed -i 's/^NAME=.*/NAME="Lumenora"/' /usr/lib/os-release && \
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Lumenora"/' /usr/lib/os-release && \
    find /etc/skel/.config/ -type f -name "*.sh" -exec chmod +x {} + && \
    find /etc/skel/.config/ml4w/scripts/ -type f -exec chmod +x {} + && \
    find /etc/skel/.config/hypr/scripts/ -type f -exec chmod +x {} + && \
    useradd -m -G wheel lumen && \
    echo "lumen:lumen" | chpasswd

RUN bootc container lint
