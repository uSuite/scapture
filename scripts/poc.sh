#!/bin/zsh
# Phase 0 proof of concept of sCapture: place a window at a fixed frame,
# capture its content rect into the active PoC case folder, print the step.
# The Swift agent replaces it from Phase 2 (docs/02-tech-stack.md).
#
#   poc.sh use <case-id>        make a case under $SCAPTURE_ROOT the active one
#   poc.sh shot [app] [title]   capture into the active case
#   poc.sh                      print the active case and its step count
#
# Geometry defaults are the Guide-Shot scripts', all in points:
#   POC_FRAME  window "x y w h"                       200 50 1520 980
#   POC_INSET  cut off "top left bottom right"        87 1 1 1
#   POC_SCALE  output pixels per point, 1 or 2        2

setopt err_exit no_unset pipe_fail
zmodload zsh/datetime

root=${SCAPTURE_ROOT:-$HOME/Pictures/scapture}
state=${XDG_CONFIG_HOME:-$HOME/.config}/scapture/poc-case
frame=(${=POC_FRAME:-200 50 1520 980})
inset=(${=POC_INSET:-87 1 1 1})
scale=${POC_SCALE:-2}

die() {
  print -u2 -r -- "poc: $*"
  exit 1
}

count() {
  local files=($1/*.(png|jpg|jpeg)(N))
  print $#files
}

pixels() {
  sips -g pixelWidth -g pixelHeight $1 | awk '/pixel/ { printf "%s ", $2 }'
}

active() {
  [[ -r $state ]] || die "no active case, run: poc.sh use <case-id>"
  local dir=$(<$state)
  [[ -d $dir ]] || die "the active case is gone: $dir"
  print -r -- $dir
}

use() {
  [[ $1 =~ '^poc-[a-z0-9]+(-[a-z0-9]+)+$' ]] || die "not a case id: $1"
  local found=($root/$1(N/) $root/*/$1(N/))
  (( $#found == 1 )) || die "$1: $#found folders under $root, need one"
  mkdir -p ${state:h}
  print -r -- $found[1] > $state
  print -r -- "${found[1]:t}  $(count $found[1])"
}

# Prints kept when the window was frontmost and in place already, else moved.
place() {
  osascript - "$1" "$2" $frame <<'EOF' || die "cannot place a $1 window: not running, no such window, or no Accessibility"
on run {appName, titlePart, x, y, w, h}
  set wanted to {{x as integer, y as integer}, {w as integer, h as integer}}
  tell application "System Events" to tell application process appName
    set wasFront to frontmost
    if titlePart is "" then
      set win to window 1
    else
      set win to first window whose name contains titlePart
    end if
    set p to position of win
    set s to size of win
    set placed to {p, s} is wanted
    if not placed then
      set position of win to item 1 of wanted
      set size of win to item 2 of wanted
    end if
  end tell
  tell application appName to activate
  if wasFront and placed then return "kept"
  return "moved"
end run
EOF
}

shot() {
  # Assigned apart from local, which would hide a die in the substitution.
  local t0=$EPOCHREALTIME dir placed
  local app=${1:-Google Chrome} title=${2:-}
  dir=$(active)
  placed=$(place "$app" "$title")
  [[ $placed == kept ]] || sleep 0.3
  local x=$(( frame[1] + inset[2] )) y=$(( frame[2] + inset[1] ))
  local w=$(( frame[3] - inset[2] - inset[4] )) h=$(( frame[4] - inset[1] - inset[3] ))
  local name=scap-$(strftime %Y-%m-%d-%H%M%S $EPOCHSECONDS) n=1
  local letters=({a..z}) file=$dir/$name.png
  # A same-second capture gets b, c and on; -1 would sort before the first one,
  # both in a plain sort and in Finder's order.
  while [[ -e $file ]]; do
    (( n < 26 )) || die "26 captures in one second"
    file=$dir/$name$letters[++n].png
  done
  # Rendered outside the case and renamed in, so a watcher never sees half a file;
  # screencapture refuses dot names there and exits 0 on failure, hence the size test.
  local tmp=$(mktemp -d)/${file:t}
  screencapture -x -t png -R$x,$y,$w,$h $tmp && [[ -s $tmp ]] || {
    rm -rf ${tmp:h}
    die "screencapture wrote no image, check Screen Recording and the folder"
  }
  local size=($(pixels $tmp))
  if (( size[1] != w * scale )); then
    (( size[1] < w * scale )) && print -u2 "poc: upsampling ${size[1]} to $(( w * scale )) pixels wide"
    sips -z $(( h * scale )) $(( w * scale )) -s dpiWidth $(( 72 * scale )) -s dpiHeight $(( 72 * scale )) $tmp >/dev/null
    size=($(pixels $tmp))
  fi
  # mv -n exits 0 when the name was taken meanwhile; try the next one.
  while mv -n $tmp $file && [[ -e $tmp ]]; do
    (( n < 26 )) || die "26 captures in one second, the last one is in ${tmp:h}"
    file=$dir/$name$letters[++n].png
  done
  rmdir ${tmp:h}
  local ms
  printf -v ms %.0f $(( (EPOCHREALTIME - t0) * 1000 ))
  print -r -- "${dir:t}  step $(count $dir)  ${size[1]}x${size[2]}  $ms ms  ${file:t}"
}

case ${1:-} in
  use) use ${2:?case id}
    ;;
  shot) shift
    shot "$@"
    ;;
  '') local_dir=$(active)
    print -r -- "${local_dir:t}  $(count $local_dir)"
    ;;
  *) die "usage: poc.sh [use <case-id> | shot [app] [title]]"
    ;;
esac
