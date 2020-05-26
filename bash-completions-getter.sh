
# Author: Brian Beffa <brbsix@gmail.com>
# Updated by: Marco Trevisan <mail@3v1n0.net>
# Original source: https://brbsix.github.io/2015/11/29/accessing-tab-completion-programmatically-in-bash/
# License: LGPLv3 (http://www.gnu.org/licenses/lgpl-3.0.txt)
#

compopt() {
    # Override default compopt
    # TODO, to implement when possible
    return 0
}

parse_complete_options() {
    unset COMPLETE_ACTION
    unset COMPLETE_ACTION_TYPE
    unset COMPLETE_SUPPORTED_COMMANDS

    while getopts ":abcdefgjksuvp:D:o:A:G:W:F:C:X:P:S:" opt; do
        case ${opt} in
            F|C)
                [ -n "$COMPLETE_ACTION" ] && return 2
                local optarg=${OPTARG#\'}
                COMPLETE_ACTION=${optarg%\'}
                COMPLETE_ACTION_TYPE=${opt}
            ;;
            X)
                # TODO, but to support this we also need to handle compopt and -o
            ;;
            W)
                # TODO, but to support this we also need to handle compopt and -o
            ;;
        esac
    done

    [ -z "$COMPLETE_ACTION" ] && return 1

    COMPLETE_SUPPORTED_COMMANDS=()
    for ((i = $OPTIND; i <= ${#@}; i++)); do
        COMPLETE_SUPPORTED_COMMANDS+=("${@:$i:1}")
    done
}

get_completions() {
    local COMP_CWORD COMP_LINE COMP_POINT COMP_WORDS COMP_WORDBREAKS
    local completion COMPREPLY=() cmd_name

    # load bash-completion if necessary
    declare -F _completion_loader &>/dev/null || {
        if [ -n "${ZSH_BASH_COMPLETIONS_FALLBACK_PATH}" ] &&
           [ -f "${ZSH_BASH_COMPLETIONS_FALLBACK_PATH}/completions" ]; then
            source "${ZSH_BASH_COMPLETIONS_FALLBACK_PATH}/completions"
        elif [ -f /etc/bash_completion ]; then
            source /etc/bash_completion
        elif [ -f /usr/share/bash-completion/bash_completion ]; then
            source /usr/share/bash-completion/bash_completion
        fi
    }

    COMP_LINE=${ZSH_BUFFER}
    COMP_POINT=${ZSH_CURSOR:-${#COMP_LINE}}
    COMP_WORDBREAKS=${ZSH_WORDBREAKS}
    COMP_WORDS=(${ZSH_WORDS[@]})
    cmd_name=${ZSH_NAME}


    # add '' to COMP_WORDS if the last character of the command line is a space
    [[ "${COMP_LINE[@]: -1}" = ' ' ]] && COMP_WORDS+=('')

    # index of the last word as fallback
    COMP_CWORD=${ZSH_CURRENT:-$(( ${#COMP_WORDS[@]} - 1 ))}

    # load completion
    _completion_loader "$cmd_name"

    # detect completion function or command
    if [[ "$(complete -p "$cmd_name" 2>/dev/null)" =~ \
          ^complete[[:space:]]+(.+) ]]; then
        local args=${BASH_REMATCH[1]};
        parse_complete_options $args
        completion="$COMPLETE_ACTION"
    else
        return 1;
    fi

    # ensure completion was detected
    [[ -n "$completion" ]] || return 1

    # execute completion function or command (exporting the needed variables)
    # This may fail if compopt is called, but there's no easy way to pre-fill
    # the bash input with some stuff, using only bashy things.
    local cmd=("$completion")
    cmd+=("$cmd_name")
    cmd+=("'${COMP_WORDS[$COMP_CWORD]}'")

    if [ $((COMP_CWORD-1)) -ge 0 ]; then
        cmd+=("'${COMP_WORDS[$((COMP_CWORD-1))]}'");
    else
        cmd+=('');
    fi

    if [ "$COMPLETE_ACTION_TYPE" == 'C' ]; then
        export COMP_CWORD COMP_LINE COMP_POINT COMP_WORDS COMP_WORDBREAKS
        COMPREPLY=($(${cmd[@]}))
    else
        ${cmd[@]}
    fi

    # print completions to stdout
    for ((i = 0; i < ${#COMPREPLY[@]}; i++)); do
        echo "${COMPREPLY[$i]%%*( )}"
    done
}
