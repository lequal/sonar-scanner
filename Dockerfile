# Builder image for analysis tools
FROM debian:10.5-slim AS builder

# Install tools from sources
RUN echo 'deb http://ftp.fr.debian.org/debian/ bullseye main contrib non-free' >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        curl=7.74.0-* \
        # for C/C++ tools
        make=4.3-* \
        g\+\+=4:10.2.1-* \
        python3=3.9.1-* \
        libpcre3-dev=2:8.39-* \
        unzip=6.0-* \
        xz-utils=5.2.4-* \
        # for Frama-C
        ocaml=4.11.1-* \
        ocaml-findlib=1.8.1-* \
        libfindlib-ocaml-dev=1.8.1-* \
        libocamlgraph-ocaml-dev=1.8.8-* \
        libyojson-ocaml-dev=1.7.0-* \
        libzarith-ocaml-dev=1.11-* \
        menhir=20201216-* \
    # Hadolint tool
    && curl -ksSLO https://github.com/hadolint/hadolint/releases/download/v1.21.0/hadolint-Linux-x86_64 \
    && mv /hadolint-Linux-x86_64 /hadolint \
    # sonar-scanner
    && curl -ksSLO https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.4.0.2170.zip \
    && unzip sonar-scanner-cli-4.4.0.2170.zip \
    && mv /sonar-scanner-4.4.0.2170 /sonar-scanner \
    # CppCheck
    && curl -ksSLO https://downloads.sourceforge.net/project/cppcheck/cppcheck/1.90/cppcheck-1.90.tar.gz \
    && tar -zxvf cppcheck-1.90.tar.gz \
    && make -C cppcheck-1.90/ install \
            MATCHCOMPILER="yes" \
            FILESDIR="/usr/share/cppcheck" \
            HAVE_RULES="yes" \
            CXXFLAGS="-O2 -DNDEBUG -Wall -Wno-sign-compare -Wno-unused-function -Wno-deprecated-declarations" \
    # RATS (and expat)
    && curl -ksSLO https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/rough-auditing-tool-for-security/rats-2.4.tgz \
    && curl -ksSLO http://downloads.sourceforge.net/project/expat/expat/2.0.1/expat-2.0.1.tar.gz \
    && tar -xvzf expat-2.0.1.tar.gz \
    && cd expat-2.0.1 \
    && ./configure \
    && make \
    && make install \
    && cd .. \
    && tar -xzvf rats-2.4.tgz \
    && cd rats-2.4 \
    && ./configure --with-expat-lib=/usr/local/lib \
    && make \
    && make install \
    && ./rats \
    && cd .. \
    # Frama-C
    && curl -ksSLO https://frama-c.com/download/frama-c-20.0-Calcium.tar.gz \
    && tar -zxvf frama-c-20.0-Calcium.tar.gz \
    && cd frama-c-20.0-Calcium \
    && ./configure --disable-gui --disable-wp \
    && make \
    && make install \
    && cd .. \
    # Infer
    && curl -ksSLO https://github.com/facebook/infer/releases/download/v0.17.0/infer-linux64-v0.17.0.tar.xz \
    && tar -C /opt -Jxvf infer-linux64-v0.17.0.tar.xz

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
            "$SONAR_SCANNER_HOME/.sonar/cache" \
            "$SONAR_SCANNER_HOME/.pylint.d" \
    && chown -R sonar-scanner:sonar-scanner \
            "$SONAR_SCANNER_HOME" \
            "$SONAR_SCANNER_HOME/.sonar" \
            "$SONAR_SCANNER_HOME/.pylint.d" \
            "$SRC_DIR" \
    && chmod -R 777 \
            "$SONAR_SCANNER_HOME/.sonar" \
            "$SONAR_SCANNER_HOME/.pylint.d" \
            "$SRC_DIR"

# Add hadolint from builder stage
COPY --from=builder /hadolint /opt
RUN chmod 700 /opt/hadolint

# Add sonar-scanner from builder
COPY --from=builder /sonar-scanner/bin/sonar-scanner \
    "$SONAR_SCANNER_HOME/bin"
COPY --from=builder /sonar-scanner/lib \
    "$SONAR_SCANNER_HOME/lib"
# and our default sonar-scanner.properties
COPY conf/sonar-scanner.properties "$SONAR_SCANNER_HOME/conf"

# Add CppCheck from builder stage
COPY --from=builder /usr/share/cppcheck /usr/share/cppcheck
COPY --from=builder /usr/bin/cppcheck /usr/bin
COPY --from=builder /usr/bin/cppcheck-htmlreport /usr/bin

# Add RATS and Frama-C from builder stage
COPY --from=builder /usr/local /usr/local

# Add Infer from builder stage
COPY --from=builder /opt/infer-linux64-v0.17.0/bin /opt/infer-linux64-v0.17.0/bin
COPY --from=builder /opt/infer-linux64-v0.17.0/lib /opt/infer-linux64-v0.17.0/lib

# Add CNES pylintrc A_B, C, D
COPY pylintrc.d/ /opt/python/

# Download CNES pylint extension
ADD https://github.com/cnescatlab/cnes-pylint-extension/archive/v5.0.0.tar.gz \
    /tmp/python/

# Install tools
RUN echo 'deb http://ftp.fr.debian.org/debian/ bullseye main contrib non-free' >> /etc/apt/sources.list \
    && apt-get update \
    && mkdir -p /usr/share/man/man1 \
    && apt-get install -y --no-install-recommends \
            # Needed by sonar-scanner
            openjdk-11-jre-headless=11.0.10* \
            # Needed by Pylint
            python3=3.9.1-* \
            python3-pip=20.1.1-* \
            # Vera++
            vera\+\+=1.2.1-* \
            # Shellcheck
            shellcheck=0.7.1-* \
            # Needed by Frama-C
            ocaml-findlib=1.8.1-* \
            libocamlgraph-ocaml-dev=1.8.8-* \
            libzarith-ocaml=1.11-* \
            libyojson-ocaml=1.7.0-* \
            # Needed by Infer
            libsqlite3-0=3.34.1-* \
            libtinfo5=6.2* \
            python2.7=2.7.18-* \
            # Compilation tools needed by Infer
            gcc=4:10.2.1-* \
            g\+\+=4:10.2.1-* \
            clang=1:11.0-* \
            make=4.3-* \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/man \
    # Install pylint and CNES pylint extension
    && mkdir -p /opt/python/cnes-pylint-extension-5.0.0 \
    && tar -xvzf /tmp/python/v5.0.0.tar.gz -C /tmp/python \
    && mv /tmp/python/cnes-pylint-extension-5.0.0/checkers /opt/python/cnes-pylint-extension-5.0.0/ \
    && rm -rf /tmp/python \
    && pip install --no-cache-dir \
            setuptools-scm==3.5.0 \
            pytest-runner==5.2 \
            wrapt==1.12.1 \
            six==1.14.0 \
            lazy-object-proxy==1.4.3 \
            mccabe==0.6.1 \
            isort==4.3.21 \
            typed-ast==1.4.1 \
            astroid==2.4.0 \
            pylint==2.5.0 \
    # Infer
    && ln -s "/opt/infer-linux64-v0.17.0/bin/infer" /usr/local/bin/infer

# Make sonar-scanner, CNES pylint, C/C++ and hadolint tools executable
ENV PYTHONPATH="$PYTHONPATH:/opt/python/cnes-pylint-extension-5.0.0/checkers" \
    PATH="$SONAR_SCANNER_HOME/bin:/usr/local/bin:$PATH" \
    PYLINTHOME="$SONAR_SCANNER_HOME/.pylint.d" \
    JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64" \
    PATH="/opt:$PATH"

# Switch to an unpriviledged user
USER sonar-scanner

# Set the entrypoint (a SonarSource script) and the default command (sonar-scanner)
COPY --chown=sonar-scanner:sonar-scanner scripts/entrypoint.sh /usr/bin
ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]
CMD [ "sonar-scanner" ]
