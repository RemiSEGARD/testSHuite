# testSHuite

testSHuite is a functional test written in Shell

## Usage

```
Usage:
    ./testsuite.sh [directories ...]              Run the testsuite with the given argument
    ./testsuite.sh --html [directories ...]       Runs the testsuite, outputing in an html file 'output.html'
    ./testsuite.sh -h|--help                      Shows this
```

testSHuite will automatically look for files in subdirectories ending with the `.yaml` extention.
If you wish to run only one subdirectory(ies)'s testsuite(s), you can input the directory(ies) in the argument

## Writing tests

There are multiple settings you can use to write your tests. Some are **Optional** and some are *Non optional*

### Global setting

Here is the list of global settings:
 - **binary**: Path to the binary for the testsuite
 - *testsuite_name*: Name of the testsuite. Defaults\ to the name of the yaml file
 - *ref*: Name of the reference binary
 - *variables*: Allows you to declare variables in a list, see below for more informations

### Tests-specific setting

Here is the list of settings for each tests:
 - **name**: Name of the test
 - *exit_code*: Expected exit code. Defaults to 0, ignored if *ref* is set
 - *args*: Argument for the execution of the program
 - *fatal*: Set to *true* to stop the execution of the testsuite if the test fails or *false*. Defaults to *false*
 - *timeout*: Time (in seconds) before the program is forcefully closed and the test is considered failed
 - *stdin*: Input string to write in the standart input of the program
 - *stdout*: Expected output of the program. Ignored if *ref* is set
 - *stderr*: Expected error output of the program. Ignored if *ref* is set

### Variables

You can use variables in order to avoid typing the same thing many times.
To do so, add in the *variables* sections of your global options the variables of your choice:
```yaml
global:
  variables:
    - path: /usr/bin/
    - args: -iam --an-argument
```

Variables can only be expanded in the tests. To do so, you have to put the name of the variable inside "<<>>"
```yaml
...
  - test:
      name: test
      args: <<path>>bash <<args>> # will expand to /usr/bin/bash -iam --an-argument
```


### File format

**Make sure to follow the instructions below, or the parsing of the file may fail.**
**Do not hesitate to refer to the samples in the repository**

You must first write global options.
You then need to start a 'testsuite' section in which you will write your tests.
```yaml
global:
  binary: __binary__
  testsuite_name: __name__
 
testsuite:
  - test:
      name: __test_name1__
      args: __arguments__
      exit_code: 0
      timeout: 10
  - test:
      name: __test_name2__
      stdin: ...
      exit_code: 1
```

You can add sections in a testsuite. A name for each section has to be provided:
```yaml
global:
  binary: echo
  testsuite_name: sections

testsuite:
  - section:
      name: no_arg
      testsuite:
        - test:
            name: firt_no_arg
            args: firt no arg
  - section:
      name: sub_section
      testsuite:
        - section:
            name: first_sub
            testsuite:
              - test:
                  name: fsub_test1
                  args: fsub test1
              - test:
                  name: fsub_test2
                  args: fsub test2
```
