FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

COPY install-pkgs.sh /install-pkgs.sh

RUN bash /install-pkgs.sh

ENV GVM_LIBS_VERSION="21.4.4" \
    OPENVAS_SCANNER_VERSION="21.4.4" \
    GVMD_VERSION="21.4.5" \
    GSA_VERSION="21.4.4" \
    GSAD_VERSION="21.4.4" \
    gvm_tools_version="21.10.0" \
    OPENVAS_SMB_VERSION="21.4.0" \
    OSPD_OPENVAS_VERSION="21.4.4" \
    python_gvm_version="21.11.0" \
    INSTALL_PREFIX="/usr/local" \
    SOURCE_DIR="/source" \
    BUILD_DIR="/build" \
    INSTALL_DIR="/install"
    
RUN mkdir -p $SOURCE_DIR && \
    mkdir -p $BUILD_DIR

    #
    # install libraries module for the Greenbone Vulnerability Management Solution
    #
    
RUN curl -f -L https://github.com/greenbone/gvm-libs/archive/refs/tags/v$GVM_LIBS_VERSION.tar.gz -o $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz && \
    curl -f -L https://github.com/greenbone/gvm-libs/releases/download/v$GVM_LIBS_VERSION/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc -o $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc && \
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz && \
    mkdir -p $BUILD_DIR/gvm-libs && cd $BUILD_DIR/gvm-libs && \
    cmake $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release \
        -DSYSCONFDIR=/etc \
        -DLOCALSTATEDIR=/var && \
    make -j$(nproc) && \
    make install

    #
    # Install Greenbone Vulnerability Manager (GVMD)
    #    
    
RUN curl -f -L https://github.com/greenbone/gvmd/archive/refs/tags/v$GVMD_VERSION.tar.gz -o $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz && \
    curl -f -L https://github.com/greenbone/gvmd/releases/download/v$GVMD_VERSION/gvmd-$GVMD_VERSION.tar.gz.asc -o $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc && \
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz && \
    mkdir -p $BUILD_DIR/gvmd && cd $BUILD_DIR/gvmd && \
    cmake $SOURCE_DIR/gvmd-$GVMD_VERSION \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release \
        -DLOCALSTATEDIR=/var \
        -DSYSCONFDIR=/etc \
        -DGVM_DATA_DIR=/var \
        -DGVMD_RUN_DIR=/run/gvmd \
        -DOPENVAS_DEFAULT_SOCKET=/run/ospd/ospd-openvas.sock \
        -DGVM_FEED_LOCK_PATH=/var/lib/gvm/feed-update.lock \
        -DDEFAULT_CONFIG_DIR=/etc/default \
        -DLOGROTATE_DIR=/etc/logrotate.d && \
    make -j$(nproc) && \
    make install

    #
    # Install Greenbone Security Assistant (GSA)
    #
    
RUN curl -f -L https://github.com/greenbone/gsa/archive/refs/tags/v$GSA_VERSION.tar.gz -o $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz && \
    curl -f -L https://github.com/greenbone/gsa/releases/download/v$GSA_VERSION/gsa-$GSA_VERSION.tar.gz.asc -o $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc && \
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz && \
    cd $SOURCE_DIR/gsa-$GSA_VERSION && \
    rm -rf build && \
    yarnpkg && \
    yarnpkg build && \
    mkdir -p $INSTALL_PREFIX/share/gvm/gsad/web/ && \
    cp -r build/* $INSTALL_PREFIX/share/gvm/gsad/web/
    
    #
    # Install Greenbone Security Agent Daemon (GSAD)
    #
    
RUN curl -f -L https://github.com/greenbone/gsad/archive/refs/tags/v$GSAD_VERSION.tar.gz -o $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz && \
    curl -f -L https://github.com/greenbone/gsad/releases/download/v$GSAD_VERSION/gsad-$GSAD_VERSION.tar.gz.asc -o $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz.asc && \
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gsad-$GSAD_VERSION.tar.gz && \
    mkdir -p $BUILD_DIR/gsad && cd $BUILD_DIR/gsad && \
    cmake $SOURCE_DIR/gsad-$GSAD_VERSION \
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
    
RUN curl -f -L https://github.com/greenbone/openvas-smb/archive/refs/tags/v$OPENVAS_SMB_VERSION.tar.gz -o $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz && \
    curl -f -L https://github.com/greenbone/openvas-smb/releases/download/v$OPENVAS_SMB_VERSION/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc -o $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc && \
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz && \
    mkdir -p $BUILD_DIR/openvas-smb && cd $BUILD_DIR/openvas-smb && \
    cmake $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install
    
    #
    # Install Open Vulnerability Assessment System (OpenVAS) Scanner of the Greenbone Vulnerability Management (GVM) Solution
    #
    
RUN curl -f -L https://github.com/greenbone/openvas-scanner/archive/refs/tags/v$OPENVAS_SCANNER_VERSION.tar.gz -o $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz && \
    curl -f -L https://github.com/greenbone/openvas-scanner/releases/download/v$OPENVAS_SCANNER_VERSION/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc -o $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc && \
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz && \
    mkdir -p $BUILD_DIR/openvas-scanner && cd $BUILD_DIR/openvas-scanner && \
    cmake $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_BUILD_TYPE=Release \
        -DSYSCONFDIR=/etc \
        -DLOCALSTATEDIR=/var \
        -DOPENVAS_FEED_LOCK_PATH=/var/lib/openvas/feed-update.lock \
        -DOPENVAS_RUN_DIR=/run/ospd && \
    make -j$(nproc) && \
    make install

    #
    # Install Open Scanner Protocol for OpenVAS
    #
    
RUN curl -f -L https://github.com/greenbone/ospd-openvas/archive/refs/tags/v$OSPD_OPENVAS_VERSION.tar.gz -o $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz && \
    curl -f -L https://github.com/greenbone/ospd-openvas/releases/download/v$OSPD_OPENVAS_VERSION/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc -o $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc && \
    tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz && \
    cd $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION && \
    python3 -m pip install . --no-warn-script-location
    
    #
    # Install Greenbone Vulnerability Management Python Library
    #
    
RUN pip3 install python-gvm==$python_gvm_version  
    
    #
    # Install GVM-Tools
    #
    
RUN python3 -m pip install gvm-tools && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/openvas.conf && ldconfig

COPY report_formats/* /report_formats/

COPY greenbone-feed-sync-patch.txt /greenbone-feed-sync-patch.txt

RUN patch /usr/local/sbin/greenbone-feed-sync /greenbone-feed-sync-patch.txt

COPY sshd_config /sshd_config

COPY scripts/* /

RUN chmod +x /*.sh

CMD '/start.sh'
