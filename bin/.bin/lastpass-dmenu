#!/usr/bin/env bash
# by Christopher Peterson
# https://chrispeterson.info

######
# Argpargse
######

read -r -d '' helpoutput <<EOF
  Usage:
    ${0} [OPTIONS]... [copy|type]

      Pop-up LastPass desktop quick-search. Puts the selection into the
      clipboard or has xdotool type it out for you.

  Options:
    -n, --notes
        When this option is set, this script will try to return the secure note
        from the selection instead of the password. Lastpass-cli itself does
        not support "attached" notes, so only the actual note field is
        returned.
        Default: disabled

  Positional arguments:
    [copy|type]
        Specify what to do with the selected password/note: copy to the
        clipboard, or have xdotool type it for you.

  Examples
    Put the password into the clipboard:
        ${0} copy

    Have the script type out the password for you:
        ${0} type

    Copy any secure notes in the selection:
        ${0} --notes copy

  Security
    Please make copy mode more secure by limiting X selection requests on the
    clipboard. Lpass-cli can do this by setting the environment variable
    \`LPASS_CLIPBOARD_COMMAND\` as per lastpass-cli documentation.

    xclip can do this by limiting the number of paste requests that can come
    from this selection:
        export LPASS_CLIPBOARD_COMMAND="xclip -selection clipboard -in -l 1"

    xsel cannot limit paste requests, but can time out the selection (ms):
        export LPASS_CLIPBOARD_COMMAND="xsel -t 5000 --input --clipboard"

EOF

if [ $# -eq 0 ]; then
  echo "${helpoutput}"
  exit 0
fi

# Before running through `getopts`, translate out convenient long-versions
# within $@ because we're using bash built-in getopts which does not support
# long args
for opt in "$@"; do
  shift
  case "${opt}" in
    '--notes') set -- "$@" '-n' ;;
    '--help')  set -- "$@" '-h' ;;
    *)         set -- "$@" "${opt}" ;;
  esac
done

# Defaults
lpass_field='password'

# Back to the beginning now and get our opts
OPTIND=1
while getopts ':nh' opt; do
  case "${opt}" in
    h)
      echo "${helpoutput}"
      exit 0
      ;;
    n)
      lpass_field='notes'
      ;;
    *)
      echo "Invalid option ${OPTARG}" >&2
      echo "${helpoutput}" >&2
      exit 1
      ;;
  esac
done

shift $(( OPTIND - 1 ))
subcommand="${1}"
if [ "${subcommand}" != 'type' ] && [ "${subcommand}" != 'copy' ]; then
  echo "Incorrect subcommand. Must be 'type' or 'copy'" >&2
  echo
  echo "${helpoutput}" >&2
  exit 1
fi

######
# Main
######

# List all entries in LastPass vault into dmenu formatted as follows
# Folder/subfolder/Name of Site [username at site] [id: id for lookup]
IFS=$'\n' entries=($(lpass ls --long |
  cut -d ' ' -f 3- |
  sed 's/\[username: /[/' |
  sed 's/\(.*\)\(\[.*\]\) \(\[.*\]\)/\1 \3 \2/')
)

if ! lpass status; then
  echo 'Lastpass-cli returning failed status.' <&2
  # shellcheck disable=SC2016
  echo 'Please run `lpass login [your_username]`' >&2
  exit 1
fi

# Get selection from user via dmenu
selid=$(
  printf '%s\n' "${entries[@]}" |
  dmenu -i -p 'LastPass: ' -l 7 |
  sed 's/^.*\[id: \([0-9]\{1,\}\)\].*$/\1/'
  )
if [ -z "${selid}" ]; then
  echo 'Nothing selected. Exiting.' >&2
  exit 0
fi

if [ "${subcommand}" == 'type' ]; then
  lpass show "--${lpass_field}" "${selid}" | xdotool -
else
  # Result to clipboard
  lpass show --clip "--${lpass_field}" "${selid}"
fi
