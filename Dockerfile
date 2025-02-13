FROM ubuntu:noble

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

COPY install-pkgs.sh /install-pkgs.sh

RUN bash /install-pkgs.sh

ENV GVM_LIBS_VERSION="v22.17.0" \
    OPENVAS_SCANNER_VERSION="v23.15.3" \
    GVMD_VERSION="v25.0.0" \
    GSA_VERSION="24.2.0" \
    GSAD_VERSION="v24.2.1" \
    gvm_tools_version="v25.1.1" \
    OPENVAS_SMB_VERSION="v22.5.6" \
    OSPD_OPENVAS_VERSION="v22.8.0" \
    PG_GVM_VERSION="main" \
    SYNC_VERSION="main" \
    INSTALL_PREFIX="/usr/local" \
    SOURCE_DIR="/source" \
    BUILD_DIR="/build" \
    INSTALL_DIR="/install"
    
RUN mkdir -p $SOURCE_DIR && \
    mkdir -p $BUILD_DIR

    #
    # install libraries module for the Greenbone Vulnerability Management Solution
    #
    
RUN cd $SOURCE_DIR && \
    git clone --branch $GVM_LIBS_VERSION https://github.com/greenbone/gvm-libs.git && \
    mkdir -p $BUILD_DIR/gvm-libs && cd $BUILD_DIR/gvm-libs && \
    cmake $SOURCE_DIR/gvm-libs \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release \
        -DSYSCONFDIR=/etc \
        -DLOCALSTATEDIR=/var && \
    make -j$(nproc) && \
    make install

    #
    # Install Greenbone Vulnerability Manager (GVMD)
    #    
    
RUN cd $SOURCE_DIR && \
    git clone --branch $GVMD_VERSION https://github.com/greenbone/gvmd.git && \
    mkdir -p $BUILD_DIR/gvmd && cd $BUILD_DIR/gvmd && \
    cmake $SOURCE_DIR/gvmd \
	-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
	-DCMAKE_BUILD_TYPE=Release \
	-DLOCALSTATEDIR=/var \
	-DSYSCONFDIR=/etc \
	-DGVM_DATA_DIR=/var \
	-DGVMD_RUN_DIR=/run/gvmd \
	-DOPENVAS_DEFAULT_SOCKET=/run/ospd/ospd-openvas.sock \
	-DGVM_FEED_LOCK_PATH=/var/lib/gvm/feed-update.lock \
	-DSYSTEMD_SERVICE_DIR=/lib/systemd/system \
	-DLOGROTATE_DIR=/etc/logrotate.d && \
    make -j$(nproc) && \
    make install
    
    #
    # Install PostgreSQL GVM (pg-gvm)
    #    
    
RUN cd $SOURCE_DIR && \
    git clone --branch $PG_GVM_VERSION https://github.com/greenbone/pg-gvm.git && \
    mkdir -p $BUILD_DIR/pg-gvm && cd $BUILD_DIR/pg-gvm && \
    cmake $SOURCE_DIR/pg-gvm \
        -DCMAKE_BUILD_TYPE=Release \
	-DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql && \
    make -j$(nproc) && \
    make install

    #
    # Install Greenbone Security Assistant (GSA)
    #
    
RUN cd $SOURCE_DIR && \
    curl -f -L https://github.com/greenbone/gsa/releases/download/v$GSA_VERSION/gsa-dist-$GSA_VERSION.tar.gz -o $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz && \	
    mkdir -p $SOURCE_DIR/gsa && \
    tar -C $SOURCE_DIR/gsa -xvzf $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz && \
    mkdir -p $INSTALL_PREFIX/share/gvm/gsad/web/ && \
    cp -rv $SOURCE_DIR/gsa/* $INSTALL_PREFIX/share/gvm/gsad/web/
    
    #
    # Install Greenbone Security Agent Daemon (GSAD)
    #
    
RUN cd $SOURCE_DIR && \
    git clone --branch $GSAD_VERSION https://github.com/greenbone/gsad.git && \
    mkdir -p $BUILD_DIR/gsad && cd $BUILD_DIR/gsad && \
    cmake $SOURCE_DIR/gsad \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release \
        -DSYSCONFDIR=/etc \
        -DLOCALSTATEDIR=/var \
        -DGVMD_RUN_DIR=/run/gvmd \
        -DGSAD_RUN_DIR=/run/gsad \
        -DLOGROTATE_DIR=/etc/logrotate.d && \
    make -j$(nproc) && \
    make install
	
    #
    # install smb module for the OpenVAS Scanner
    #
    
RUN cd $SOURCE_DIR && \
    git clone --branch $OPENVAS_SMB_VERSION https://github.com/greenbone/openvas-smb.git && \
    mkdir -p $BUILD_DIR/openvas-smb && cd $BUILD_DIR/openvas-smb && \
    cmake $SOURCE_DIR/openvas-smb \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install
    
    #
    # Install Open Vulnerability Assessment System (OpenVAS) Scanner of the Greenbone Vulnerability Management (GVM) Solution
    #
    
RUN cd $SOURCE_DIR && \
    git clone --branch $OPENVAS_SCANNER_VERSION https://github.com/greenbone/openvas-scanner.git && \
    mkdir -p $BUILD_DIR/openvas-scanner && cd $BUILD_DIR/openvas-scanner && \
    cmake $SOURCE_DIR/openvas-scanner \
    	-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release \
	-DINSTALL_OLD_SYNC_SCRIPT=OFF \
        -DSYSCONFDIR=/etc \
        -DLOCALSTATEDIR=/var \
        -DOPENVAS_FEED_LOCK_PATH=/var/lib/openvas/feed-update.lock \
        -DOPENVAS_RUN_DIR=/run/ospd && \
    make -j$(nproc) && \
    make install
	
    #
    # Install Open Scanner Protocol for OpenVAS
    #
    
RUN cd $SOURCE_DIR && \
    git clone --branch $OSPD_OPENVAS_VERSION https://github.com/greenbone/ospd-openvas.git && \
    cd $SOURCE_DIR/ospd-openvas && \
    python3 -m pip install --prefix /usr . --no-warn-script-location
	
    #
    # Install OpenVAS Daemon (replaces Notus) and RUST/Cargo Packages
    #
	
RUN echo "Installing Openvas Daemon" && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain 1.81.0 -y && \
    . "$HOME/.cargo/env" && \
    mkdir -p $INSTALL_DIR/openvasd/usr/local/bin && \
    cd $SOURCE_DIR/openvas-scanner/rust/src/openvasd && \
    cargo build --release && \
    cd $SOURCE_DIR/openvas-scanner/rust/src/scannerctl && \
    cargo build --release && \
    cp -v ../../target/release/openvasd $INSTALL_DIR/openvasd/usr/local/bin/ && \
    cp -v ../../target/release/scannerctl $INSTALL_DIR/openvasd/usr/local/bin/ && \
    cp -rv $INSTALL_DIR/openvasd/* /
	
    #
    # Install Greenbone Feed Sync
    #
    
RUN mkdir -p $INSTALL_DIR/greenbone-feed-sync && \
    python3 -m pip install --root=$INSTALL_DIR/greenbone-feed-sync --no-warn-script-location greenbone-feed-sync && \
    cp -rv $INSTALL_DIR/greenbone-feed-sync/* /
    
    #
    # Install Greenbone Vulnerability Management Python Library
    #
    
RUN python3 -m pip install --user python-gvm --break-system-packages
    
    #
    # Install GVM-Tools
    #
    
RUN mkdir -p $INSTALL_DIR/gvm-tools && \
    python3 -m pip install --root=$INSTALL_DIR/gvm-tools --no-warn-script-location gvm-tools && \
    cp -rv $INSTALL_DIR/gvm-tools/* / && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf && ldconfig

COPY report_formats/* /report_formats/
COPY sshd_config /sshd_config
COPY scripts/* /
RUN chmod +x /*.sh
COPY branding/* /branding/
RUN chmod +x /branding/*.sh
RUN bash /branding/brand.sh
ENV NMAP_PRIVILEGED=1
RUN setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip /usr/bin/nmap
CMD '/start.sh'
