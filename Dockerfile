# Builder image for other analysis tools
FROM debian:10.5-slim AS builder

# Get sonar-scanner and C/C++ tools sources
ADD https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.4.0.2170.zip \
    https://downloads.sourceforge.net/project/cppcheck/cppcheck/1.90/cppcheck-1.90.tar.gz \
    /

# Compile CppCheck from source
RUN apt-get update \
    && apt-get install -y \
        make \
        g\+\+ \
        python3 \
        libpcre3-dev \
        unzip \
    # Unzip sonar-scanner
    && unzip sonar-scanner-cli-4.4.0.2170.zip \
    && mv /sonar-scanner-4.4.0.2170 /sonar-scanner \
    # Compile CppCheck
    && tar -zxvf cppcheck-1.90.tar.gz \
    && make -C cppcheck-1.90/ install \
            MATCHCOMPILER="yes" \
            FILESDIR="/usr/share/cppcheck" \
            HAVE_RULES="yes" \
            CXXFLAGS="-O2 -DNDEBUG -Wall -Wno-sign-compare -Wno-unused-function -Wno-deprecated-declarations"

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

# Add CNES pylintrc A_B, C, D
COPY pylintrc.d/ /opt/python/

# Download CNES pylint extension
ADD https://github.com/cnescatlab/cnes-pylint-extension/archive/v5.0.0.tar.gz \
    /tmp/python/

# Install tools
RUN echo 'deb http://ftp.fr.debian.org/debian/ bullseye main contrib non-free' >> /etc/apt/sources.list \
    && apt-get update \
    && mkdir -p /usr/share/man/man1 \
    && apt-get install -y \
            openjdk-11-jre-headless \
            python3 \
            python3-pip \
            vera\+\+=1.2.1-* \
            shellcheck=0.7.1-* \
    && rm -rf /var/lib/apt/lists/* \
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
            pylint==2.5.0

# Make sonar-scanner, CNES pylint and Frama-C executable
ENV PYTHONPATH="$PYTHONPATH:/opt/python/cnes-pylint-extension-5.0.0/checkers" \
    PATH="$SONAR_SCANNER_HOME/bin:/usr/local/bin:$PATH" \
    PYLINTHOME="$SONAR_SCANNER_HOME/.pylint.d"

# Switch to an unpriviledged user
USER sonar-scanner

# Set the entrypoint (a SonarSource script) and the default command (sonar-scanner)
COPY --chown=sonar-scanner:sonar-scanner scripts/entrypoint.sh /usr/bin
ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]
CMD [ "sonar-scanner" ]
