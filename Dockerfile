# Builder image for analysis tools
FROM debian:10.5-slim AS builder

# Install tools from sources
RUN echo 'deb http://ftp.fr.debian.org/debian/ bullseye main contrib non-free' >> /etc/apt/sources.list \
    && apt-get update
    #for yosys
RUN apt-get install -o APT::Immediate-Configure=false -y build-essential clang bison flex \
        libreadline-dev gawk tcl-dev libffi-dev git \
        graphviz xdot pkg-config python3 libboost-system-dev \
        libboost-python-dev libboost-filesystem-dev zlib1g-dev \
    && git clone https://github.com/YosysHQ/yosys.git \
    && cd yosys \
    && make config-gcc \
    && make \
    && make install \
    && cd .. 
    #for ghdl
    #FIXME:  this ghdl install procedure as to be updated to include gcov coverage
 RUN apt-get install -o APT::Immediate-Configure=false  -y gnat git gcc make zlib1g-dev\ 
    && git clone https://github.com/ghdl/ghdl.git \
    && cd ghdl \
    && ./configure --prefix=/usr/local \
    && make \
    && make install \
    && cd .. 
    #for  ghdl-yosys-plugin
RUN git clone https://github.com/ghdl/ghdl-yosys-plugin.git \
    && cd ghdl-yosys-plugin \
    && make \
    && make install \
    && cd .. 
    # sonar-scanner
RUN apt-get install -y curl unzip\
    && curl -ksSLO https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.4.0.2170.zip \
    && unzip sonar-scanner-cli-4.4.0.2170.zip \
    && mv /sonar-scanner-4.4.0.2170 /sonar-scanner 
    #Addon for RC scanner
RUN curl -ksSLO https://github.com/VHDLTool/sonar-VHDLRC/releases/download/V3.3/rc-scanner-4.1-linux.tar.xz \
    && unxz rc-scanner-4.1-linux.tar.xz \
    && tar xvf rc-scanner-4.1-linux.tar \
    && mkdir /sonar-scanner/rc \
    && cp -r /rc-scanner-4.1-linux/rc/* /sonar-scanner/rc/ 

################################################################################

# Final image based on the official sonar-scanner image
FROM debian:10.5-slim

LABEL maintainer="CATLab <catlab@cnes.fr>"

# Set variables for the sonar-scanner
ENV SRC_DIR=/usr/src \
    SONAR_SCANNER_HOME=/opt/sonar-scanner \
    SONAR_USER_HOME=/opt/sonar-scanner/.sonar

# Same workdir as the offical sonar-scanner image
WORKDIR ${SRC_DIR}

# Add an unprivileged user
RUN addgroup sonar-scanner \
    && adduser \
            --home "$SONAR_SCANNER_HOME" \
            --ingroup sonar-scanner \
            --disabled-password \
            --gecos "" \
            sonar-scanner \
    && mkdir -p "$SONAR_SCANNER_HOME/bin" \
            "$SONAR_SCANNER_HOME/lib" \
            "$SONAR_SCANNER_HOME/conf" \
            "$SONAR_SCANNER_HOME/rc" \
            "$SONAR_SCANNER_HOME/.sonar/cache" \
            "$SONAR_SCANNER_HOME/.pylint.d" \
    && chown -R sonar-scanner:sonar-scanner \
            "$SONAR_SCANNER_HOME" \
            "$SONAR_SCANNER_HOME/.sonar" \
            "$SONAR_SCANNER_HOME/rc" \
            "$SONAR_SCANNER_HOME/.pylint.d" \
            "$SRC_DIR" \
    && chmod -R 777 \
            "$SONAR_SCANNER_HOME/.sonar" \
            "$SONAR_SCANNER_HOME/rc" \
            "$SONAR_SCANNER_HOME/.pylint.d" \
            "$SRC_DIR"

# Add sonar-scanner from builder
COPY --from=builder /sonar-scanner/bin/sonar-scanner \
    "$SONAR_SCANNER_HOME/bin"
COPY --from=builder /sonar-scanner/lib \
    "$SONAR_SCANNER_HOME/lib"
# and our default sonar-scanner.properties
COPY conf/sonar-scanner.properties "$SONAR_SCANNER_HOME/conf"
#add VHDL RC engine
COPY --from=builder /sonar-scanner/rc/ \
    "$SONAR_SCANNER_HOME/rc"
#give ownership to user (for write and execution) for VHDL RC engine
RUN chown -R sonar-scanner:sonar-scanner "$SONAR_SCANNER_HOME/rc"
RUN chmod -R 777 "$SONAR_SCANNER_HOME/rc" 
# add yosys from builder
COPY --from=builder /usr/local/bin/yosys /usr/local/bin/yosys
COPY --from=builder /usr/local/bin/yosys-abc /usr/local/bin/yosys-abc
COPY --from=builder /usr/local/bin/yosys-config /usr/local/bin/yosys-config
COPY --from=builder /usr/local/bin/yosys-filterlib /usr/local/bin/yosys-filterlib
COPY --from=builder /usr/local/bin/yosys-smtbmc /usr/local/bin/yosys-smtbmc
# add ghdl from builder
COPY --from=builder /usr/local/lib/libghdl.a /usr/local/lib/libghdl.a 
COPY --from=builder /usr/local/lib/libghdl.link /usr/local/lib/libghdl.link 
COPY --from=builder /usr/local/lib/libghdl-2_0_0_dev.so /usr/local/lib/libghdl-2_0_0_dev.so 
COPY --from=builder /usr/local/lib/libghdlvpi.so /usr/local/lib/libghdlvpi.so 
COPY --from=builder /usr/local/lib/ghdl /usr/local/lib/ghdl
COPY --from=builder /usr/local/bin/ghdl /usr/local/bin/ghdl 
#set yosys plugins
COPY --from=builder /usr/local/share/yosys /usr/local/share/yosys

# Install tools
RUN echo 'deb http://ftp.fr.debian.org/debian/ bullseye main contrib non-free' >> /etc/apt/sources.list \
    && apt-get update 
RUN mkdir -p /usr/share/man/man1 
    ##x needed for eclipse
RUN apt-get install -o APT::Immediate-Configure=false -y xvfb libswt-gtk-4-jni libswt-gtk-4-java openjdk-11-jre
    ## needed for ghdl
RUN apt-get install -o APT::Immediate-Configure=false -y gnat
    ##missing lib for yosys
RUN apt-get install -o APT::Immediate-Configure=false -y libreadline8 libtcl8.6
    ## clean apt
RUN rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/man 

#setup environnement variables
ENV  PATH="$SONAR_SCANNER_HOME/bin:/usr/local/bin:$PATH" \
    JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64" \
    DISPLAY=":0"

# Make sonar-scanner executable
# Switch to an unpriviledged user
USER sonar-scanner
#add fake screen kickstart . this fake screen is needed by eclipse
COPY --chown=sonar-scanner:sonar-scanner scripts/kickstartfakedisplay.sh /usr/bin
# copy the entrypoint (a SonarSource script) and the default command (sonar-scanner)
COPY --chown=sonar-scanner:sonar-scanner scripts/entrypoint.sh /usr/bin
# Set the entrypoint
ENTRYPOINT [ "/usr/bin/kickstartfakedisplay.sh" ]
CMD [ "sonar-scanner" ]
