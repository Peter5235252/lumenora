FROM ghcr.io/wayblueorg/hyprland:43

# 1. Enable COPRs and Install Packages
RUN dnf copr enable -y llamatron/bazaar && \
    dnf install -y --skip-unavailable \
    fastfetch swww bazaar distrobox \
    mangohud SwayNotificationCenter

# 2. Inject ML4W dotfiles (Directly to /etc/skel)
COPY files/etc /etc

# 3. Rebrand and Fix Permissions
RUN sed -i 's/^NAME=.*/NAME="Lumenora"/' /usr/lib/os-release && \
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Lumenora"/' /usr/lib/os-release && \
    find /etc/skel/.config/ -type f -name "*.sh" -exec chmod +x {} + && \
    find /etc/skel/.config/ml4w/scripts/ -type f -exec chmod +x {} + && \
    find /etc/skel/.config/hypr/scripts/ -type f -exec chmod +x {} +

RUN useradd -m -G wheel lumen && \
    echo "lumen:lumen" | chpasswd

# 5. Final system check
RUN bootc container lint
