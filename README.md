# CNES sonar-scanner image \[client\]

![](https://github.com/cnescatlab/sonar-scanner/workflows/CI/badge.svg)
![](https://github.com/cnescatlab/sonar-scanner/workflows/CD/badge.svg)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/f5f71dea84ce4020ab15a99fc841a696)](https://www.codacy.com/gh/cnescatlab/sonar-scanner?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=lequal/sonar-scanner&amp;utm_campaign=Badge_Grade)

> Docker environment containing open source code analysis tools configured by CNES and dedicated to Continuous Integration.

This image is a pre-configured sonar-scanner image derived from [Docker-CAT](https://github.com/cnescatlab/docker-cat). It contains the same tools for code analysis.

SonarQube itself is an opensource project on GitHub : [SonarSource/sonarqube](https://github.com/SonarSource/sonarqube).

For versions and changelog: [GitHub Releases](https://github.com/cnescatlab/sonar-scanner/releases).

## Features

This image is based on the official sonar-scanner image, namely [sonarsource/sonar-scanner-cli:4.4](https://hub.docker.com/r/sonarsource/sonar-scanner-cli), and offers additional features.

Additional features are:

* Embedded tools
    * see the [list](#analysis-tools-included)
* Configuration files
    * [pylintrc](#how-to-use-embedded-CNES-pylintrc)

_This image is made to be used in conjunction with a pre-configured SonarQube server image that embeds all necessary plugins and configuration: [cnescatlab/sonarqube](https://github.com/cnescatlab/sonarqube). It is, however, not mandatory to use it._

## User guide

This image is available on Docker Hub: [lequal/sonar-scanner](https://hub.docker.com/r/lequal/sonar-scanner/).

This image is based on the official SonarQube [sonar-scanner-cli docker image](https://hub.docker.com/r/sonarsource/sonar-scanner-cli) and suffer from the same limitations. Consequently, should you analyze .NET projects, use the SonarScanner for MSBuild.

1. Write a `sonar-project.properties` at the root of your project
    * For information on what to write in it, see the [official SonarQube documentation](https://docs.sonarqube.org/7.9/analysis/analysis-parameters/)
1. Execute the sonar-scanner on the project by running this image from the root of the project
    ```sh
    $ docker run \
            --rm \
            -u "$(id -u):$(id -g)" \
            -e SONAR_HOST_URL="url of your SonarQube instance" \
            -v "$(pwd):/usr/src" \
            lequal/sonar-scanner
    ```
    * If the SonarQube server is running in a container on the same computer, you will need to connect both containers (server and client) to the same bridge so that they can communicate. To do so:
      ```sh
      $ docker network create -d bridge sonarbridge
      $ docker network connect sonarbridge "name of your sonarqube container"
      # add the following option to the command line when running the lequal/sonar-scanner
      --net sonarbridge
      ```

### How to use embedded tools

Not only does this image provide a sonar-scanner, but also a set of open source code analysis tools. All available tools are listed [below](#analysis-tools-included). They can be used from the image by changing the arguments of the container when running one.

```sh
# Example with shellcheck
$ docker run \
        --rm \
        -u "$(id -u):$(id -g)" \
        -v "$(pwd):/usr/src" \
        lequal/sonar-scanner \
        shellcheck --color always -s bash -f checkstyle my-script.bash
# where my-script.bash is a file in the current working directory
```

For information on how to use these tools, refer to the official documentation of the tool.

#### How to use embedded CNES pylintrc

There are 3 `pylintrc` embedded in the image under `/opt/python`:

* `pylintrc_RNC_sonar_2017_A_B`
* `pylintrc_RNC_sonar_2017_C`
* `pylintrc_RNC_sonar_2017_D`

To use one of these files when running pylint from within the container:

```sh
# pylint with a CNES pylintrc
$ docker run \
        --rm \
        -u "$(id -u):$(id -g)" \
        -v "$(pwd):/usr/src" \
        lequal/sonar-scanner \
        pylint --rcfile=/opt/python/pylintrc_RNC_sonar_2017_A_B my-script.py
# where my-script.py is a python module in the current working directory
```

To import pylint results in SonarQube see the [official documentation](https://docs.sonarqube.org/7.9/analysis/languages/python/#header-3). (Summed up: activate at least one pylint rule in the Quality Profile the project uses for Python and set `sonar.python.pylint.reportPath` in `sonar-project.properties`.)

### Examples usage in CI

This image was made for CI, hence here are some examples. Make sur to use the right URL for your SonarQube instance instead of `my-sonarqube.com`.

_These examples still need to be tested._

#### Jenkins

Here is an example of a jenkins file that call this image to analyze a project.

```groovy
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh '''
                    mkdir -p .sonarcache
                    docker run --rm \
                      -u "$(id -u):$(id -g)" \
                      -e SONAR_HOST_URL="https://my-sonarqube.com" \
                      -v "$(pwd):/usr/src" \
                      -v ".sonarcache:/opt/sonar-scanner/.sonar/cache" \
                      lequal/sonar-scanner
                '''

                cache {
                  caches {
                    path {
                      '.sonarcache'
                    }
                  }
                }
            }
        }
    }
}
```

#### GitHub Actions

Here is a GitHub Actions job of a GitHub Actions workflow that call this image to analyze a project.

```yml
jobs:
  sonar-scanning:
    name: Run CNES sonar-scanner
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Cache sonar-scanner data
        uses: actions/cache@v2
        with:
          path: .sonarcache
          key: sonar-scanner-cache
      - run: |
          mkdir -p .sonarcache
          docker run --rm \
                    -u "$(id -u):$(id -g)" \
                    -e SONAR_HOST_URL="https://my-sonarqube.com" \
                    -v "$(pwd):/usr/src" \
                    -v ".sonarcache:/opt/sonar-scanner/.sonar/cache" \
                    lequal/sonar-scanner
```

#### Travis CI

Here is a Travis CI script step, in a `.travis.yml`, to analyze a project with this image.

```yml
cache:
  directories:
    - /home/travis/.sonarcache

script:
  - mkdir -p /home/travis/.sonarcache
  - docker run --rm \
        -u "$(id -u):$(id -g)" \
        -e SONAR_HOST_URL="https://my-sonarqube.com" \
        -v "$(pwd):/usr/src" \
        -v "/home/travis/.sonarcache:/opt/sonar-scanner/.sonar/cache" \
        lequal/sonar-scanner
```

#### GitLab-CI

Here is GitLab-CI job, in a `.gitlab-ci.yml`, to analyze a project with this image.

```yml
sonar-scanning:
  stage: test
  cache:
    key: sonar-scanner-job
    paths:
      - .sonarcache
  script:
    - mkdir -p .sonarcache
    - docker run --rm \
              -u "$(id -u):$(id -g)" \
              -e SONAR_HOST_URL="https://my-sonarqube.com" \
              -v "$(pwd):/usr/src" \
              -v ".sonarcache:/opt/sonar-scanner/.sonar/cache" \
              lequal/sonar-scanner
```

## Analysis tools included

| Tool                                                                           | Version              | 
|--------------------------------------------------------------------------------|----------------------|
| [sonar-scanner](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/) | 4.4.0.2170           |
| [ShellCheck](https://github.com/koalaman/shellcheck)                           | 0.7.1                |
| [pylint](http://pylint.pycqa.org/en/latest/user_guide/index.html)              | 2.5.0                |
| [CNES pylint extension](https://github.com/cnescatlab/cnes-pylint-extension)   | 5.0.0                |
| [CppCheck](https://github.com/danmar/cppcheck)                                 | 1.90                 |
| [Vera++](https://bitbucket.org/verateam/vera/wiki/Home)                        | 1.2.1                |

## Developer's guide

_Note about branch naming_: if a new feature needs modifications to be made both on the server image and this one, it is strongly advised to give the same name to the branches on both repositories because the CI workflow of this image will try to use the server image built from the same branch.

### How to build the image

It is a normal docker image. Thus, it can be built with the following commands.

```sh
# from the root of the project
$ docker build -t lequal/sonar-scanner .
```

To then run a container with this image see the [user guide](#user-guide).

To run the tests and create your own ones see the [test documentation](https://github.com/cnescatlab/sonar-scanner/tree/develop/tests).

## How to contribute

If you experienced a problem with the image please open an issue. Inside this issue please explain us how to reproduce this issue and paste the log. 

If you want to do a PR, please put inside of it the reason of this pull request. If this pull request fixes an issue please insert the number of the issue or explain inside of the PR how to reproduce this issue.

All details are available in [CONTRIBUTING](https://github.com/cnescatlab/.github/blob/master/CONTRIBUTING.md).

Bugs and feature requests: [issues](https://github.com/cnescatlab/sonar-scanner/issues)

To contribute to the project, read [this](https://github.com/cnescatlab/.github/wiki/CATLab's-Workflows) about CATLab's workflows for Docker images.

## License

Licensed under the [GNU General Public License, Version 3.0](https://www.gnu.org/licenses/gpl.txt)

This project is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.
