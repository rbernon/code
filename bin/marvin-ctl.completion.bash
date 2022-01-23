_marvin_ctl ()
{
    case "$COMP_CWORD" in
    "0"|"1") COMPREPLY=($(compgen -W "login deb win all" -- "${COMP_WORDS[COMP_CWORD]}"));;
    *) COMPREPLY=($(compgen -f -- "${COMP_WORDS[COMP_CWORD]}"));;
    esac
}
complete -o default -F _marvin_ctl marvin-ctl
