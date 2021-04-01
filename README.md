# CNES sonar-scanner image \[client\]

![](https://github.com/VHDLTool/Docker-sonar-scanner-vhdl/workflows/CI/badge.svg)
![](https://github.com/VHDLTool/Docker-sonar-scanner-vhdl/workflows/CD/badge.svg)


> Docker environment containing open source code analysis tools configured by CNES and dedicated to Continuous Integration.

This image is a pre-configured sonar-scanner image derived from [Docker-CAT](https://github.com/cnescatlab/docker-cat). It contains the same tools for code analysis and it is available on Docker Hub at [lequal/sonar-scanner](https://hub.docker.com/r/lequal/sonar-scanner/).

SonarQube itself is an opensource project on GitHub: [SonarSource/sonarqube](https://github.com/SonarSource/sonarqube).

For versions and changelog: [GitHub Releases](https://github.com/cnescatlab/sonar-scanner/releases).

:information_source: If you only need a containerized `sonar-scanner`, you better use the official image from SonarSource available on Docker Hub: [sonarsource/sonar-scanner-cli](https://hub.docker.com/r/sonarsource/sonar-scanner-cli). The official image is smaller because it does not embed any other tool.

## Features

Compared to the official [sonarsource/sonar-scanner-cli](https://hub.docker.com/r/sonarsource/sonar-scanner-cli) image, this image provides additional features.

Additional features are:

* Embedded tools
    * see the [list](#analysis-tools-included)
* Configuration files
    * [pylintrc](#how-to-use-embedded-CNES-pylintrc)
* Zamiacad eclipse rulechecker for VHDL analysis

_This image is made to be used in conjunction with a pre-configured SonarQube server image that embeds all necessary plugins and configuration: [cnescatlab/sonarqube-vhdl](https://github.com/VHDLTool/Docker-sonarqube-vhdl). 

## User guide

1. Write a `sonar-project.properties` at the root of your project
    * For information on what to write in it, see the [official SonarQube documentation](https://docs.sonarqube.org/7.9/analysis/analysis-parameters/)
1. Execute the sonar-scanner on the project by running this image from the root of the project
    ```sh
    $ docker run \
            --rm \
            -u "$(id -u):$(id -g)" \
            -e SONAR_HOST_URL="url of your SonarQube instance" \
            -v "$(pwd):/usr/src" \
            lequal/sonar-scanner-vhdl
    ```
    This docker command is equivalent to `sonar-scanner -Dsonar.host.url="url of your SonarQube instance"`.
    * If the SonarQube server is running in a container on the same computer, you will need to connect both containers (server and client) to the same bridge so that they can communicate. To do so:
      ```sh
      $ docker network create -d bridge sonarbridge
      $ docker network connect sonarbridge "name of your sonarqube container"
      # add the following option to the command line when running the lequal/sonar-scanner-vhdl
      --net sonarbridge
      ```
    * To find you server IP you can eexecute the following commands:   
      Get the sonarqube server Container ID by running:
      ```sh
      docker ps
      ```
      Use this Container ID to get the dedicated IP address:
      ```sh
      docker inspect -f '{{range .NetworkSettings.Networks}} {{.IPAddress}}{{end}}' <MySonarqubeDockerID>
       ```

This image suffers from the same limitations as the official SonarQube [sonarsource/sonar-scanner-cli](https://hub.docker.com/r/sonarsource/sonar-scanner-cli) image.

* If you need to analyze .NET projects, you must use the SonarScanner for MSBuild.
* If you want to save the sonar-scanner cache, you must create the directory to bind mount in the container before running it. For more information, see [SonarQube documentation](https://docs.sonarqube.org/8.4/analysis/scan/sonarscanner/#header-6).

### How to use embedded tools

Not only does this image provide a sonar-scanner, but also a set of open source code analysis tools. All available tools are listed [below](#analysis-tools-included). They can be used from the image by changing the arguments of the container when running one.

```sh
# Example with shellcheck
$ docker run \
        --rm \
        -u "$(id -u):$(id -g)" \
        -v "$(pwd):/usr/src" \
        lequal/sonar-scanner-vhdl \
        shellcheck --color always -s bash -f checkstyle my-script.bash
# where my-script.bash is a file in the current working directory
```

For information on how to use these tools, refer to their official documentation or [Cnescatlab documentation for sonarqube original docker](https://github.com/cnescatlab/sonarqube)



### Examples usage in CI

This image was made for CI, hence here are some examples. Make sur to use the right URL for your SonarQube instance instead of `my-sonarqube.com`.

_These examples still need to be tested._

#### GitLab-CI

Here is GitLab-CI job, in a `.gitlab-ci.yml`, to analyze a project with this image.

```yml
#this wokflow works only on bash linux

variables:
  #SONAR_TOKEN_CICD # this variable is set in Gitlab project variable parameter
  #SONAR_HOST_URL # this variable is set in Gitlab project variable paramete
  GIT_DEPTH: 1
 
stages:
   - analysecode

sonarqube-job1:
   allow_failure: false
   stage: analysecode
   tags: 
     - sonarqube
   script: 
      - docker run --rm 
               --network host 
               -u "$(id -u):$(id -g)"
               -e SONAR_HOST_URL=$SONAR_HOST_URL 
               -v "${CI_PROJECT_DIR}:/usr/src:rw" 
               lequal/sonar-scanner-vhdl -Dsonar.qualitygate.wait=true 
               -Dsonar.login=$SONAR_TOKEN_CICD -X
```

## Analysis tools included

| Tool                                                                           | Version       | Default report file |
|--------------------------------------------------------------------------------|---------------|---------------------|
| [sonar-scanner](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/) | 4.4.0.2170    |                     |
| [ShellCheck](https://github.com/koalaman/shellcheck)                           | 0.7.1         |                     |
| [pylint](http://pylint.pycqa.org/en/latest/user_guide/index.html)              | 2.5.0         | pylint-report.txt   |
| [CNES pylint extension](https://github.com/cnescatlab/cnes-pylint-extension)   | 5.0.0         |                     |
| [CppCheck](https://github.com/danmar/cppcheck)                                 | 1.90          | cppcheck-report.xml |
| [Vera++](https://bitbucket.org/verateam/vera/wiki/Home)                        | 1.2.1         | vera-report.xml     |
| [RATS](https://code.google.com/archive/p/rough-auditing-tool-for-security/)    | 2.4           | rats-report.xml     |
| [Frama-C](https://frama-c.com/index.html)                                      | 20.0          |                     |
| [Infer](https://fbinfer.com/)                                                  | 0.17.0        |                     |
| [VHDLRC](https://github.com/VHDLTool/sonar-VHDLRC)                             | 3.3           |                     |


## Developer's guide

_Note about branch naming_: if a new feature needs modifications to be made both on the server image and this one, it is strongly advised to give the same name to the branches on both repositories because the CI workflow of this image will try to use the server image built from the same branch.

### How to build the image

It is a normal docker image. Thus, it can be built with the following commands.

```sh
# from the root of the project
$ docker build -t lequal/sonar-scanner-vhdl .
```

To then run a container with this image see the [user guide](#user-guide).

To run the tests and create your own ones see the [test documentation](https://github.com/cnescatlab/sonar-scanner/tree/develop/tests).

### Debugging the image
If analysis doesn't perform correctly you can inspect the image by doing the following sequence:
1. launch the container with a shell (the entrypoint script is not ran).   
In this case, a bridge was created as sonarbridge to link with the soanrqube container which can be address with IP 172.18.0.2. Notice that the container was given a name : lequalscanner.
```sh
docker run --name lequalscanner --net sonarbridge --rm  -e SONAR_HOST_URL="http://172.18.0.2:9000" -it --entrypoint /bin/sh lequal/sonar-scanner-vhdl 

```
2. Run the following script (on a new windows powershell)
```sh
#get container ID and store it in a variable
$DOCKERID=docker ps -aqf "name=lequalscanner"  
#copy your sources in the scanner container (you're supposed to be located in your sources directory when executing this script)
docker cp .  ${DOCKERID}:/usr/src
#change ownership of the sources
docker exec -u root  ${DOCKERID} bash -c 'chown -R sonar-scanner:sonar-scanner /usr/src'
```
3. Do what ever you needed to be done. You can launch sonar scanner analysis by running the following command in the container shell and then debug the result
```sh
kickstartfakedisplay.sh -X
```
if you want to use a custom scanner command line you have to initialise first the display with `Xvfb :0 &` and then launch your custom scanner with its command lines:
```sh
./rc-scanner-4.1-linux/bin/rc-scanner -X -Dsonar.host.url="http://172.19.0.2:9000"
```
## How to contribute

If you experienced a problem with the image please open an issue. Inside this issue please explain us how to reproduce this issue and paste the log. 

If you want to do a PR, please put inside of it the reason of this pull request. If this pull request fixes an issue please insert the number of the issue or explain inside of the PR how to reproduce this issue.

All details are available in [CONTRIBUTING](https://github.com/cnescatlab/.github/blob/master/CONTRIBUTING.md).

Bugs and feature requests: [issues](https://github.com/cnescatlab/sonar-scanner/issues)

To contribute to the project, read [this](https://github.com/cnescatlab/.github/wiki/CATLab's-Workflows) about CATLab's workflows for Docker images.

## License

Licensed under the [GNU General Public License, Version 3.0](https://www.gnu.org/licenses/gpl.txt)

This project is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.
