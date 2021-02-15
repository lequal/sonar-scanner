# Test documentation

The `tests/` folder contains both test scripts and some dummy projects to analyze.

## List of scripted integration tests

1. Java
    * file: java.bash
    * purpose: Check that the Java language is supported and that the right plugins are executed.
1. Shell
    * file: shell.bash
    * purpose: Check that the Shell language is supported and that the right plugins are executed.
1. ShellCheck
    * file: shellcheck.bash
    * purpose: Check that ShellCheck can be launched from within the container to analyze scripts in the project.
1. Fortran
    * file: fortran.bash
    * purpose: Check that the Fortran 77 and 90 languages are supported and that the right plugins are executed.
1. Python
    * file: python.bash
    * purpose: Check that the Python language is supported and that CNES Quality Profiles are usable.
1. Pylint
    * file: pylint.bash
    * purpose: Check that Pylint can be launched from within the container to analyze Python projects.
1. Import pylint results in SonarQube
    * file: import_pylint_results.bash
    * purpose: Check that issues revealed by a pylint analysis can be imported in SonarQube.
1. C/C++
    * file: c_cpp.bash
    * purpose: Check that the C and C++ languages are supported and that CNES Quality Profiles are usable.
1. CppCheck
    * file: cppcheck.bash
    * purpose: Check that cppcheck can be launched from within the container to analyze C/C++ projects.
1. Import CppCheck results
    * file: import_cppcheck_results.bash
    * purpose: Check that issues revealed by a cppcheck analysis can be imported in SonarQube.
1. Vera++
    * file: vera.bash
    * purpose: Check that vera++ can be launched from within the container to analyze C/C++ projects.
1. Import Vera++ results
    * file: import_vera_results.bash
    * purpose: Check that issues revealed by vera++ and activated in the Quality Profile can be imported in SonarQube.
1. RATS
    * file: rats.bash
    * purpose: Check that RATS can be launched from within the container to analyze C/C++ projects.
1. Import RATS results
    * file: import_rats_results.bash
    * purpose: Check that issues revealed by RATS and activated in the Quality Profile can be imported in SonarQube.
1. Frama-C
    * file: framac.bash
    * purpose: Check that Frama-C can be launched from within the container to analyze C/C++ projects.
1. Import Frama-C results
    * file: import_framac_results.bash
    * purpose: Check that issues revealed by Frama-C and activated in the Quality Profile can be imported in SonarQube.
1. Infer
    * file: infer.bash
    * purpose: Check that Infer can be launched from within the container to analyze C/C++ projects.
1. Hadolint
    * file: hadolint.bash
    * purpose: Check that hadolint can be launched from within the container to analyze Dockerfiles.

### How to run all the tests

Before testing the image, it must be built (see the [README](https://github.com/cnescatlab/sonar-scanner#how-to-build-the-image)).

To run the tests, the following tools are required:

* `curl`
* `jq`

To run all the tests, use the test script like this:

```sh
# from the root of the project
$ ./tests/run_tests.bash
```

## How to run a specific test

1. Create a docker bridge
    * ```sh
      $ docker network create sonarbridge
      ```
1. Run a container of the SonarQube server
    * ```sh
      $ docker run --name lequalsonarqube \
              -d --rm \
              -p 9000:9000 \
              -e SONARQUBE_ADMIN_PASSWORD=adminpassword \
              --net sonarbridge \
              lequal/sonarqube:latest
      ```
* Wait until it is configured
    * The message `[INFO] CNES SonarQube: ready!` is logged.
    * To see the logs of a container running in background
      ```sh
      $ docker container logs -f lequalsonarqube
      Ctrl-C # once the container is ready
      ```
* Run a test script with
    * ```sh
      $ ./tests/shell.bash
      # Environment variables may be modified
      $ SONARQUBE_ADMIN_PASSWORD=pass ./tests/shell.bash
      ```
* Test the exit status of the script with `echo $?`
    * zero => success
    * non-zero => failure

## List of options and environment variables used by the tests

Options:
* `--no-server-run`: if this option is specified, the script will not run a `lequal/sonarqube` container or create a bridge network. It will only launch the tests. In this case, make sur to set necessary environment variables.

Environment variables:
* `SONARQUBE_CONTAINER_NAME`: the name to give to the container running the `lequal/sonarqube` image.
* `SONARQUBE_ADMIN_PASSWORD`: the password of the admin account on the server.
* `SONARQUBE_URL`: URL of `lequal/sonarqube` container if already running without trailing `/` from the scanner container. e.g. http://mycontainer:9000 Use it only if no container name was given.
* `SONARQUBE_LOCAL_URL`: URL of `lequal/sonarqube` container if already running without trailing `/` from the host. e.g. http://localhost:9000
* `SONARQUBE_TAG`: the tag of the `lequal/sonarqube` image to use. e.g. latest
* `SONARQUBE_NETWORK`: the name of the docker bridge used.

## How to add a new test

Tests are just scripts.

To add a test:

1. Create a file under the `tests/` folder
1. Make it executable (with `chmod u+x tests/my_test.bash` for instance)
1. Edit the script.
1. To indicate whether the test has failed or succeed, use the exit status
    * zero => success
    * non-zero => failure
1. Add the test to the [list](#list-of-scripted-integration-tests)

Note that when using `./tests/run_tests.bash` to run the new test alongside the others, only messages on STDERR will by displayed if any.
