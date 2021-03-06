#!/bin/sh
# Refer to the samples to write tests.

# Colors for pretty formatting
NC="\033[30;0m"
RED="$NC\033[31m"
REDB="$NC\033[31;1m"
ORANGE="$NC\033[33m"
GREEN="$NC\033[32m"
GREENB="$NC\033[32;1m"
BLUE="$NC\033[36m"
BLUEB="$NC\033[36;1m"
GRAY="$NC\033[30;1m"

total_tests='0'
total_succeed='0'
total_failed='0'

# "Stack" for the indent of the current sections
section_indent='0'

# Number of variables set in the testuite
total_variables='0'

HTML_output="false"
artifacts=

# Non-optional global parameters
GLOBAL_BINARY=
# Optional global parameters
TESTSUITE_NAME=
REF=

# Non-optional parameters for each test
NAME=
# Optional parameters for each test
EXIT_CODE=
BINARY=
ARGS=
STDIN=
STDOUT=
STDERR=
TIMEOUT=
FATAL=

OLDIFS="$IFS"

line_pop () {
    IFS=
    rval=0
    [ -z "$line_buf" ] && { IFS= read -r line_buf; rval=$? ; }
    line="$line_buf"
    line_buf=
    IFS="$OLDIFS"
    return "$rval"
}

line_peek () {
    OLDIFS="$IFS"
    IFS=
    rval=0
    [ -z "$line_buf" ] && { IFS= read -r line_buf; rval=$? ; }
    line="$line_buf"
    IFS="$OLDIFS"
    return "$rval"
}

remove_comments () {
    # Removes comments and removes '\' when escaping '#'
    line="$(echo $line | sed 's/\([^\]\)#.*$/\1/g')"
    line="$(echo $line | sed 's/\\#/#/g')"
}

reset_variables () {
    for i in $(seq 0 "$(($total_variables - 1))"); do
        unset _var_$(eval echo \$var_n$i)
        unset "var_n${i}"
    done
    total_variables='0'
}

add_variable () {
    # I need to make some kind of map, I don't want to use bash lists since
    # I want to be POSIX-complient
    # I want to make a variable with an index in the name, linked to the name 
    # of the variable, which i can then expand using eval. 
    # I also need to add a prefix to the variable names to avoid overriding my own variables
    # Here's an example:
    # YAML:
    #   variables:
    #     path: i/am/the/path
    #     args: -iam --the-args
    #
    # results in the "map":
    # var_n0 -> path => _var_path -> "i/am/the/path"
    # var_n1 -> args => _var_args -> "-iam --the-args"

    # Create a variable to store the name
    eval "var_n${total_variables}='$1'"
    # Store the content of the variable
    eval "_var_$1='$2'"
    total_variables=$((total_variables + 1))
}

expand_variables () {
    IFS=$(printf "\t\n ")
    for i in $(seq 0 "$(($total_variables - 1))"); do
        case "$line" in
            *"<<$(eval echo \$var_n${i})>>"*)
                expect_var="<<$(eval echo \$var_n${i})>>"
                var_result="$(eval echo \" \"\$_var_$(eval echo \"\$var_n${i}\")\"\" | sed 's/\//\\\//g')"
                line=$(echo "${line}" | sed "s/$expect_var/$var_result/g")
                ;;
        esac
    done
    IFS=
}

parse_global_options () {
    # Resets the content of global parameters
    GLOBAL_BINARY=
    TESTSUITE_NAME=
    REF=
    reset_variables
    section_indent='0'
    stdout_indent=
    nb_sections=
    while true; do
        line_peek
        remove_comments line
        # Strip line
        line=$(echo $line | sed 's/^ *//g' | sed 's/ *$//g')
        current="$(echo $line | sed 's/\n/\\n/g' | cut --delimiter=' ' -f 1)"
        case "$current" in
            "binary:")
                GLOBAL_BINARY=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "testsuite_name:")
                TESTSUITE_NAME=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "ref:")
                REF=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "variables:")
                line_pop
                while true; do
                    line_peek
                    line=$(echo $line | sed 's/^ *//g' | sed 's/ *$//g')
                    case $line in
                        *-*:*)
                            add_variable "$(echo $line | sed 's/ *- *\([^:]*\) *:.*/\1/g')" "$(echo $line | sed 's/ *- *\([^:]*\) *: *//g')"
                            line_pop
                            ;;
                        "")
                            break 2
                            ;;
                        *)
                            break;
                    esac
                done
                ;;
            "precommands:")
                line_pop
                while true; do
                    line_peek
                    line=$(echo $line | sed 's/^ *//g' | sed 's/ *$//g')
                    case $line in
                        -*)
                            eval $(echo $line | cut --delimiter=' ' -f 2-)
                            line_pop
                            ;;
                        "")
                            break 2
                            ;;
                        *)
                            break;
                    esac
                done
                ;;
            "")
                break
                ;;
            *)
                printf "${RED}$(basename $0):L${LINENO}:Unknown global option \`$(echo $current | sed 's/://g')': aborting...\n"
                exit 2
                ;;
        esac
        line_pop
    done

    # If no name was given to the testuite
    if [ -z "$TESTSUITE_NAME" ]; then
        TESTSUITE_NAME="$test_file"
    fi
}

parse_test () {
    # Reseting variables
    ARGS=
    BINARY="$GLOBAL_BINARY"
    STDIN=
    STDOUT=
    STDERR=
    TIMEOUT=
    FATAL=
    ARTIFACT=
    EXIT_CODE=

    while true; do
        line_peek || break
        line=$(printf "$line" | sed 's/^ *//g' | sed 's/ *$//g' | sed -z 's/\n/\\n/g' | sed 's/\(\\.\)/\\\1/g')
        remove_comments line
        expand_variables
        current="$(echo $line | sed 's/\n/\\n/g' | cut --delimiter=' ' -f 1)"
        [ "$line" = "- test:" ] || [ "$line" = "- section:" ] && break
        case "$current" in
            "name:")
                NAME=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "exit_code:")
                EXIT_CODE=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "binary:")
                BINARY=$(echo $line | cut --delimiter=' ' -f 2-)
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
            "artifact:")
                ARTIFACT=$(echo $line | cut --delimiter=' ' -f 2-)
                ;;
            "")
                continue
                ;;
            *)
                printf "${RED}Unknown option \`$(echo $current | sed 's/://g')': aborting...\n"
                exit 2
                ;;
        esac
        line_pop
    done

    if [ -z "$FATAL" ]; then
        FATAL=false
    fi
    if [ -z "$EXIT_CODE" ]; then
        EXIT_CODE="0"
    fi
}

log_section_begin () {
    if $HTML_output; then
        echo "<button class=\"collapsible section\">$1</button>"
        echo "<div class=\"content\">"
    fi >&3
}

log_section_end () {
    if $HTML_output; then
        echo "</div>"
    fi >&3
}

log_testsuite_end_to_file () {
    if $HTML_output; then
        echo "</div>"
    fi >&3
}

log_testsuite_to_file () {
    if $HTML_output; then
        echo "<button class=\"collapsible testsuite\">$TESTSUITE_NAME</button>"
        echo "<div class=\"content\">"
    else
        echo "testuite:"
        echo "  name: ${TESTSUITE_NAME}"
        echo "  tests:"
    fi >&3
}

end_section () {
    nb_sections="$(echo $section_indent | wc -w)"
    section_indent="$(echo $section_indent | cut --delimiter=' ' -f -$((nb_sections - 1)))"
    stdout_indent="$(head -c $(($(echo $section_indent | wc -w) * 2)) < /dev/zero | tr '\0' ' ')"
    log_section_end
}

end_current_section () {
    nb_sections="$(echo $section_indent | wc -w)"
    last_indent="$(echo $section_indent | cut --delimiter=' ' -f $nb_sections)"
    while true; do
        line_peek || break
        remove_comments line
        # Strip the line
        indent=$(echo $line | sed 's/\( *\).*/\1/g' | wc -c)
        line=$(echo $line | sed 's/^ *//g' | sed 's/ *$//g')
        if [ "$line" = "- section:" ] && [ "$indent" -le "$last_indent" ]; then
            break
        fi
        line_pop
    done
    begin_section $indent

}

begin_section () {
    nb_sections="$(echo $section_indent | wc -w)"
    last_indent="$(echo $section_indent | cut --delimiter=' ' -f $nb_sections)"
    while [ ! -z "$last_indent" ] && [ "$1" -le "$last_indent" ]; do
        end_section
        nb_sections="$(echo $section_indent | wc -w)"
        last_indent="$(echo $section_indent | cut --delimiter=' ' -f $nb_sections)"
    done
    line_pop
    line_pop
    line=$(echo $line | sed 's/^ *//g' | sed 's/ *$//g')
    log_section_begin $(echo $line | cut --delimiter=' ' -f 2-)
    printf "$(head -c $(($(echo $section_indent | wc -w) * 2 - 2)) < /dev/zero | tr '\0' ' ')${BLUE}+--> ${GRAY}$(echo $line | cut --delimiter=' ' -f 2-)${NC}\n"
    stdout_indent="$(head -c $(($(echo $section_indent | wc -w) * 2 - 2)) < /dev/zero | tr '\0' ' ')${BLUE}| ${NC}"
    section_indent="$section_indent $1"
}

log_test_to_file () {
    if $HTML_output; then
        echo "<button class=\"collapsible $1 test\">$NAME</button>"
        echo "<div class=\"content\">"

        echo "<div class=\"grid-containter nospace\">" # open grid

        echo "<div class=\"stdout\">"
        echo "<button class=\"collapsible \">STDOUT</button>"
        echo "<div class=\"content\">"
        cat "/tmp/tmp.out"
        echo "</div>"
        echo "</div>"

        echo "<div class=\"stderr\">"
        echo "<button class=\"collapsible \">STDERR</button>"
        echo "<div class=\"content\">"
        cat "/tmp/tmp.err"
        echo "</div>"
        echo "</div>"

        echo "</div>"
        echo "</div>"
    else
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
    fi >&3
}

run_testsuite () {

    IFS=
    {
        line_peek
        if [ $line = "global:" ]; then
            line_pop
            parse_global_options
        fi

        printf "${BLUE}=========================================\n"
        printf "${BLUE}|| ${NC}Testsuite: $TESTSUITE_NAME\n"
        printf "${BLUE}=========================================${NC}\n"
        log_testsuite_to_file
        failed='0'
        succeeded='0'
        total='0'
        #while IFS= read -r line && [ "$line" != "testsuite:" ]; do echo $line; continue; done

        while true; do
            line_peek || break
            remove_comments line
            # Strip the line
            indent=$(echo $line | sed 's/\( *\).*/\1/g' | wc -c)
            line=$(echo $line | sed 's/^ *//g' | sed 's/ *$//g')
            if [ "$line" = "- test:" ]; then
                line_pop
                parse_test
            elif [ "$line" = "- section:" ]; then
                begin_section $indent $(echo )
                continue
            elif [ "$line" = "testsuite:" ]; then
                line_pop
                continue
            else
                printf "${RED}$(basename $0):L${LINENO}: Wrong file format \`$line', aborting...${NC}\n"
                exit 2
            fi
            # Execute with timeout if the test has one
            IFS=$(printf "\t\n ")
            if [ -z "$TIMEOUT" ]; then
                echo "$STDIN" | $BINARY $(echo $ARGS) 1>/tmp/tmp.out 2>/tmp/tmp.err
                #$BINARY $(echo -n $ARGS) <<< "$STDIN" 1>/tmp/tmp.out 2>/tmp/tmp.err
            else
                echo "$STDIN" | timeout $TIMEOUT $BINARY $ARGS 1>/tmp/tmp.out 2>/tmp/tmp.err
            fi
            RETURNED="$?"
            GOOD_OUTPUT=true
            [ ! -z "$ARTIFACT" ] && cat /tmp/tmp.out > "$ARTIFACT" && artifacts="$artifacts $ARTIFACT"

            # Test the outputs
            if [ ! -z "$REF" ]; then
                if [ -z "$TIMEOUT" ]; then
                    echo "$STDIN" | $BINARY $(echo -n $ARGS) 1>/tmp/ref.out 2>/tmp/ref.err
                else
                    echo "$STDIN" | timeout $TIMEOUT $BINARY $ARGS 1>/tmp/ref.out 2>/tmp/ref.err
                fi
                diff -u /tmp/tmp.out /tmp/ref.out || GOOD_OUTPUT=false
                diff -u /tmp/tmp.err /tmp/ref.err || GOOD_OUTPUT=false
            else
                if [ ! -z "$STDOUT" ]; then
                    echo $STDOUT | diff -u /tmp/tmp.out - >/dev/null || GOOD_OUTPUT=false
                fi
                if [ ! -z "$STDERR" ]; then
                    echo $STDERR | diff -u /tmp/tmp.err - >/dev/null || GOOD_OUTPUT=false
                fi
            fi
            IFS=
            # Recap of each test
            if [ "$RETURNED" = "$EXIT_CODE" ] && $GOOD_OUTPUT; then
                printf "${stdout_indent}${GREEN}[   ${GREENB}OK   ${GREEN}] $NC${NAME}\n"
                total_succeed=$((total_succeed + 1))
                succeeded=$((succeeded + 1))
                log_test_to_file "succeeded"
            elif $GOOD_OUTPUT; then
                printf "${stdout_indent}${RED}[   ${REDB}KO   ${RED}] $NC${NAME}\n"
                total_failed=$((total_failed + 1))
                failed=$((failed + 1))
                log_test_to_file "failed"
                #if $FATAL; then printf "${REDB}Fatal ${RED} test failed, aborting...\n" ; print_recap; return 1; fi
                if $FATAL; then end_current_section; fi
            else
                printf "${stdout_indent}${RED}[  ${REDB}DIFF  ${RED}] $NC${NAME}\n"
                total_failed=$((total_failed + 1))
                failed=$((failed + 1))
                log_test_to_file "failed"
                #if $FATAL; then printf "${REDB}Fatal ${RED} test failed, aborting...\n" ; print_recap; return 1; fi
                if $FATAL; then end_current_section; fi
            fi
            total=$((total + 1))
        done

        # Recap/end of current testsuite
        printf -- "${NC}----------------------------\n"
        printf "${NC}Tests succeeded: ${GREEN}$((succeeded))\n"
        printf "${NC}Tests failed: ${RED}$((failed))\n"
        if [ "$failed" -eq '0' ]; then
            printf "${NC}Total: ${GREENB}$(((succeeded) * 100 / total))%%${NC}\n"
        elif [ "$failed" -ne "$total" ]; then
            printf "${NC}Total: ${ORANGE}$(((succeeded) * 100 / total))%%${NC}\n"
        else
            printf "${NC}Total: ${REDB}$(((succeeded) * 100 / total))%%${NC}\n"
        fi
        total_tests=$((total_tests + total))
        for _ in $(seq $(echo $section_indent | wc -w)); do # for each remaining opened section
            log_section_end
        done
        log_testsuite_end_to_file
        return "$failed"
    } < "$1"
}

print_recap () {
    printf "${BLUEB}===================================================\n"
    printf "${BLUEB}|| ${NC}Tests succeeded: ${GREEN}$((total_succeed))\n"
    printf "${BLUEB}|| ${NC}Tests failed: ${RED}$((total_failed))\n"
    printf "${BLUEB}|| "
    if [ "$total_tests" -eq '0' ]; then
        printf "${REDB}No tests run${NC}\n"
        printf "${BLUEB}===================================================\n"
        exit 1
    fi
    if [ "$total_failed" -eq '0' ]; then
        printf "${NC}Total: ${GREENB}$(((total_tests - total_failed) * 100 / total_tests))%%${NC}\n"
    elif [ "$total_failed" -ne "$total_tests" ]; then
        printf "${NC}Total: ${ORANGE}$(((total_tests - total_failed) * 100 / total_tests))%%${NC}\n"
    else
        printf "${NC}Total: ${REDB}$(((total_tests - total_failed) * 100 / total_tests))%%${NC}\n"
    fi
    printf "${BLUEB}===================================================${NC}\n"
    $HTML_output && cat "html/tail.html" >&3
    exec 3>&- # close fd
    IFS=$(printf "\t \n")
    for artifact in $artifacts; do
        [ -e "$artifact" ] && rm $artifact
    done
    IFS=
}

run_all_args() {
    for dir in $@; do
        test_file="$(echo ${dir}/*.yaml)"
        if [ "$test_file" = "${dir}/*.yaml" ]; then continue; fi
        run_testsuite $test_file
    done
    print_recap
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage:"
    echo "    ./testsuite.sh [directories ...]              Run the testsuite with the given argument"
    echo "    ./testsuite.sh --html [directories ...]       Runs the testsuite, outputing in an html file 'output.html'"
    echo "    ./testsuite.sh -h|--help                      Shows this"
    exit 0
fi

[ -f "testsuite_log.yaml" ] && rm testsuite_log.yaml
[ -f "output.html" ] && rm output.html

if [ "$1" = "--html" ]; then
    HTML_output="true"
    exec 3>>output.html
    cat "html/head.html" >&3
    shift
else
    exec 3>>testsuite_log.yaml
fi
if [ "$1" = "--no-color" ]; then
    NC=""
    RED=""
    REDB=""
    ORANGE=""
    GREEN=""
    GREENB=""
    BLUE=""
    BLUEB=""
    GRAY=""
    shift
fi

if [ "$#" -eq '0' ]; then
    run_all_args $(ls -d */)
else
    run_all_args $@
fi

exit $( [ "$total_failed" = '0' ] )
