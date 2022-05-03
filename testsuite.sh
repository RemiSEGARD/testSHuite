#!/bin/sh
# Refer to the samples on TODO to write tests.

# Colors for pretty formatting
NC="\e[0m"
RED="$NC\e[31m"
REDB="$NC\e[31;1m"
ORANGE="$NC\e[33m"
GREEN="$NC\e[32m"
GREENB="$NC\e[32;1m"
BLUE="$NC\e[36m"
BLUEB="$NC\e[36;1m"
GRAY="$NC\e[30;1m"

total_tests='0'
total_succeed='0'
total_failed='0'

# Non-optional global parameters
BINARY=
# Optional global parameters
TESTSUITE_NAME=

# Non-optional parameters for each test
NAME=
EXIT_CODE= # This parameter has to be the last for each test.
# Optional parameters for each test
ARGS=
STDIN=
STDOUT=
STDERR=
TIMEOUT=
FATAL=

remove_comments () {
    # Removes comments and removes '\' when escaping '#'
    eval "$1=$(echo \$$1 | sed 's/\([^\]\)#.*$/\1/g')"
    eval "$1=$(echo \$$1 | sed 's/\\#/#/g')"
}

parse_global_options () {
    while IFS= read -r line; do
        remove_comments line
        # Strip line
        line=$(echo $line | sed 's/^ *//g' | sed 's/ *$//g')
        current="$(echo $line | cut --delimiter=' ' -f 1)"
        case "$current" in
            "binary:")
                BINARY=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "testsuite_name:")
                TESTSUITE_NAME=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "")
                break
                ;;
            *)
                echo -e "${RED}Unknown global option \`$(echo $current | sed 's/://g')': aborting..."
                exit 2
                ;;
        esac
    done

    # If no name was given to the testuite
    if [ -z "$TESTSUITE_NAME" ]; then
        TESTSUITE_NAME="$test_file"
    fi
    echo $BINARY
}

parse_test () {
    # Reseting variables
    ARGS=
    STDIN=
    STDOUT=
    STDERR=
    TIMEOUT=
    FATAL=

    while IFS= read -r line; do
        remove_comments line
        line=$(echo $line | sed 's/^ *//g' | sed 's/ *$//g')
        current="$(echo $line | cut --delimiter=' ' -f 1)"
        case "$current" in
            "name:")
                NAME=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "exit_code:")
                EXIT_CODE=$(echo $line | cut --delimiter=' ' -f 2-)
                break
                ;;
            "args:")
                ARGS=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "stdin:")
                STDIN=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "stdout:")
                STDOUT=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "stderr:")
                STDERR=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "timeout:")
                TIMEOUT=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "fatal:")
                FATAL=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "")
                break
                ;;
            *)
                echo -e "${RED}Unnkown option \`$(echo $current | sed 's/://g')': aborting..."
                exit 2
                ;;
        esac
    done
}

log_testsuite_to_file () {
    {
        echo "testuite:"
        echo "  name: ${TESTSUITE_NAME}"
        echo "  tests:"
    } >> testsuite_log.yaml
}

log_test_to_file () {
    {
        echo "    - result:"
        echo "        name: $NAME"
        echo "        command: $BINARY $ARGS"
        echo "        returned: $RETURNED"
        echo "        expected: $EXIT_CODE"

        echo "        stdout: | # $(cat /tmp/tmp.out | wc -l)"
        if [ -s /tmp/tmp.out ]; then
            while IFS= read -r out; do
                echo $out | sed "s/^/           /g"
            done < /tmp/tmp.out
        fi

        echo "        stderr: | # $(cat /tmp/tmp.err | wc -l)"
        if [ -s /tmp/tmp.err ]; then
            while IFS= read -r err; do
                echo $out | sed "s/^/           /g"
            done < /tmp/tmp.err
        fi
    } >> testsuite_log.yaml
}

run_testsuite () {
    {
        read -r line
        if [ $line = "global:" ]; then
            parse_global_options
        fi

        echo -e "${BLUE}========================================="
        echo -e "${BLUE}|| ${NC}Testsuite: $TESTSUITE_NAME"
        echo -e "${BLUE}=========================================${NC}"
        log_testsuite_to_file
        failed='0'
        succeeded='0'
        total='0'
        while IFS= read -r line && [ "$line" != "testsuite:" ]; do echo $line; continue; done

        while IFS= read -r line; do
            remove_comments line
            # Strip the line
            line=$(echo $line | sed 's/^ *//g' | sed 's/ *$//g')
            if [ "$line" = "- test:" ]; then
                parse_test
            else
                echo "run_testsuite: Wrong file format \`$line', aborting..."
                exit 2
            fi
            # Execute with timeout if the test has one
            if [ -z "$TIMEOUT" ]; then
                $BINARY $(echo -n $ARGS) <<< "$STDIN" 1>/tmp/tmp.out 2>/tmp/tmp.err
            else
                timeout $TIMEOUT $BINARY $ARGS <<< "$STDIN" 1>/tmp/tmp.out 2>/tmp/tmp.err
            fi
            RETURNED="$?"

            # Recap of each test
            if [ "$RETURNED" = "$EXIT_CODE" ]; then
                echo -e "${GREEN}[   ${GREENB}OK   ${GREEN}] $NC${NAME}"
                total_succeed=$((total_succeed + 1))
                succeeded=$((succeeded + 1))
                log_test_to_file
            else
                echo -e "${RED}[   ${REDB}KO   ${RED}] $NC${NAME}"
                total_failed=$((total_failed + 1))
                failed=$((failed + 1))
                log_test_to_file
            fi
            total=$((total + 1))
        done

        # Recap/end of current testsuite
        echo -e "${NC}----------------------------"
        echo -e "${NC}Tests succeeded: ${GREEN}$((succeeded))"
        echo -e "${NC}Tests failed: ${RED}$((failed))"
        if [ "$failed" -eq '0' ]; then
            echo -e "${NC}Total: ${GREENB}$(((succeeded) * 100 / total))%${NC}"
        elif [ "$failed" -ne "$total" ]; then
            echo -e "${NC}Total: ${ORANGE}$(((succeeded) * 100 / total))%${NC}"
        else
            echo -e "${NC}Total: ${REDB}$(((succeeded) * 100 / total))%${NC}"
        fi
        total_tests=$((total_tests + total))
        return "$failed"
    } < "$1"
}

run_all_args() {
    for dir in $@; do
        test_file="$(echo ${dir}/*.yaml)"
        if [ "$test_file" = "${dir}/*.yaml" ]; then continue; fi
        run_testsuite $test_file
    done
    echo -e "${BLUEB}==================================================="
    echo -e "${BLUEB}|| ${NC}Tests succeeded: ${GREEN}$((total_succeed))"
    echo -e "${BLUEB}|| ${NC}Tests failed: ${RED}$((total_failed))"
    echo -ne "${BLUEB}|| "
    if [ "$total_tests" -eq '0' ]; then
        echo -e "${REDB}No tests run${NC}"
        echo -e "${BLUEB}==================================================="
        exit 1
    fi
    if [ "$total_failed" -eq '0' ]; then
        echo -e "${NC}Total: ${GREENB}$(((total_tests - total_failed) * 100 / total_tests))%${NC}"
    elif [ "$total_failed" -ne "$total_tests" ]; then
        echo -e "${NC}Total: ${ORANGE}$(((total_tests - total_failed) * 100 / total_tests))%${NC}"
    else
        echo -e "${NC}Total: ${REDB}$(((total_tests - total_failed) * 100 / total_tests))%${NC}"
    fi
    echo -e "${BLUEB}===================================================${NC}"
}

if [ -f "testsuite_log.yaml" ]; then
    rm testsuite_log.yaml
fi

if [ "$#" -eq '0' ]; then
    run_all_args "$(ls -d */)"
else
    run_all_args $@
fi


exit $( [ "$total_failed" = '0' ] )
