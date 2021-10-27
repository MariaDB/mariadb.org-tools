# those steps are common to all images

# Create buildbot user
RUN useradd -ms /bin/bash buildbot \
    && gosu buildbot curl -so /home/buildbot/buildbot.tac \
    https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/dockerfiles/buildbot.tac \
    && echo "[[ -d /home/buildbot/.local/bin/ ]] && export PATH=\"/home/buildbot/.local/bin:\$PATH\"" >>/home/buildbot/.bashrc \
    # autobake-deb (debian/ubuntu) will need sudo rights \
    && if grep -qi "debian" /etc/os-release; then \
        usermod -a -G sudo buildbot; \
        echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers; \
    fi

# Install a recent rust toolchain needed for some arch
# see: https://cryptography.io/en/latest/installation/
# then upgrade pip and install BB worker requirements
RUN gosu buildbot curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs >/tmp/rustup-init.sh \
    # rust installer does not detect i386 arch \
    && case $(getconf LONG_BIT) in \
        "32") gosu buildbot sh /tmp/rustup-init.sh -y --default-host=i686-unknown-linux-gnu --profile=minimal ;; \
        *) gosu buildbot sh /tmp/rustup-init.sh -y --profile=minimal ;; \
    esac \
    && mv -v /home/buildbot/.cargo/bin/* /usr/local/bin \
    && rm -f /tmp/rustup-init.sh \
    && pip3 install --no-cache-dir -U pip \
    && gosu buildbot curl -so /home/buildbot/requirements.txt \
    https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/ci_build_images/requirements.txt \
    && gosu buildbot bash -c "pip3 install --no-cache-dir --no-warn-script-location -r /home/buildbot/requirements.txt"

# TODO: sync with BB steps (move to /home/buildbot)
RUN ln -s /home/buildbot /buildbot
WORKDIR /buildbot
USER buildbot
CMD ["dumb-init", "/home/buildbot/.local/bin/twistd", "--pidfile=", "-ny", "/home/buildbot/buildbot.tac"]
