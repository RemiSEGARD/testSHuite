# testSHuite

testSHuite is a functional test written in Shell

## Usage

```
./testsuite.sh [folders ...]
```

## Writing tests

There are multiple settings you can use to write your tests. Some are **Optional** and some are *Non optional*

### Global setting

Here is the list of global settings:
 - **binary**: Path to the binary for the testsuite
 - *testsuite_name*: Name of the testsuite. Defaults\ to the name of the yaml file

### Tests-specific setting

Here is the list of settings for each tests:
 - **name**: Name of the test
 - **exit_code**: Expected exit code
 - *args*: Argument for the execution of the program
 - *fatal*: Set to *true* to stop the execution of the testsuite if the test fails or *false*. Defaults to *false*
 - *timeout*: Time (in seconds) before the program is forcefully closed and the test is considered failed
 - *stdin*: Input string to write in the standart input of the program
 - *stdout*: Expected output of the program 
 - *stderr*: Expected error output of the program

### File format

**Make sure to follow the instructions below, or the parsing of the file may fail**
**Do not hesitate to refer to the samples in the repository**

You must first write global options, followed by an empty line.
You then need to start a 'testsuite' section in which you will write your tests.
Each test **MUST** finish with the 'exit_code' parameter:
```
global:
  binary: __binary__
  testsuite_name: __name__
 
testsuite:
  - test:
      name: __test_name1__
      args: __arguments__
      timeout: 10
      exit_code: 0
  - test:
      name: __test_name2__
      stdin: ...
      exit_code: 1
```
