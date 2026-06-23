FROM archlinux:latest

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Core dev environment + ssh server. Language toolchains are intentionally NOT
# baked in here — install them into $HOME (mise/asdf/yay/AUR) so they persist on
# the /home PVC across pod restarts. Rebuild this image to add system packages.
RUN pacman -Syu --noconfirm --needed \
      openssh sudo git curl wget ca-certificates \
      base-devel vim tmux zsh \
 && sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen \
 && pacman -Scc --noconfirm \
 && rm -rf /var/cache/pacman/pkg/*

# Unprivileged dev user. Passwordless sudo for in-container installs, and an
# empty login password — SSH access is gated by the tailnet ACL, not a
# credential (see apps/devbox/README and the ssh ACL on tag:devbox).
RUN useradd --create-home --shell /usr/bin/zsh dev \
 && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev \
 && chmod 0440 /etc/sudoers.d/dev \
 && passwd -d dev

# Bake the `yay` AUR helper so `yay -S <pkg>` works at runtime. makepkg refuses
# to run as root, so build as `dev`; its passwordless sudo lets makepkg call
# pacman to install build deps. yay-bin ships a prebuilt binary (no Go toolchain).
RUN su - dev -c 'git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin \
      && cd /tmp/yay-bin \
      && makepkg -si --noconfirm \
      && rm -rf /tmp/yay-bin' \
 && pacman -Scc --noconfirm \
 && rm -rf /var/cache/pacman/pkg/*

COPY zshrc /etc/zsh/zshrc
COPY sshd-devbox.conf /etc/ssh/sshd_config.d/devbox.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && grep -q 'sshd_config.d' /etc/ssh/sshd_config \
    || printf '\nInclude /etc/ssh/sshd_config.d/*.conf\n' >> /etc/ssh/sshd_config

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
