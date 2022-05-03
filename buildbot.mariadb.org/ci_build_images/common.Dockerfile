# those steps are common to all images

# Create buildbot user
RUN useradd -ms /bin/bash buildbot \
    && gosu buildbot curl -so /home/buildbot/buildbot.tac \
    # TODO move buildbot.tac to ci_build_images
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
    # for Centos7/ppcle64, specific pip packages versions \
    # and python3-devel are needed \
    && if grep -q "CentOS Linux release 7" /etc/centos-release || grep -q "Red Hat Enterprise Linux Server release 7" /etc/redhat-release && [ "$(arch)" = "ppc64le" ]; then \
        yum -y install python3-devel; \
        yum clean all; \
        pip3 install --no-cache-dir cffi==1.14.3 cryptography==3.1.1 pyOpenSSL==19.1.0 twisted[tls]==20.3.0 buildbot-worker==2.8.4; \
        gosu buildbot sh -c "mkdir -p /home/buildbot/.local/ && ln -s /usr/local/bin /home/buildbot/.local/bin"; \
    else \
        pip3 install --no-cache-dir -U pip; \
        gosu buildbot curl -so /home/buildbot/requirements.txt \
        https://raw.githubusercontent.com/MariaDB/mariadb.org-tools/master/buildbot.mariadb.org/ci_build_images/requirements.txt; \
        # https://jira.mariadb.org/browse/MDBF-329 \
        if grep -q "stretch" /etc/apt/sources.list; then \
            gosu buildbot bash -c "pip3 install --no-cache-dir --no-warn-script-location incremental"; \
        fi; \
        gosu buildbot bash -c "pip3 install --no-cache-dir --no-warn-script-location -r /home/buildbot/requirements.txt"; \
    fi \
    && if grep -qi "debian" /etc/os-release; then \
        pip3 install --no-cache-dir --no-warn-script-location python-debian junit_xml; \
    fi

# TODO: sync with BB steps (move to /home/buildbot)
RUN ln -s /home/buildbot /buildbot
WORKDIR /buildbot
USER buildbot
CMD ["dumb-init", "/home/buildbot/.local/bin/twistd", "--pidfile=", "-ny", "/home/buildbot/buildbot.tac"]
