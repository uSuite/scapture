#!/bin/zsh
# Smoke test of the built app (SC-602): a scratch config, root and case, two
# profiles on the app's own test window, once with timestamp names and once
# with case-step names; checks every file name and pixel size. The app needs
# Screen Recording (System Settings > Privacy & Security).
setopt err_exit no_unset pipe_fail

app=${APP:-build/sCapture.app}
work=$(mktemp -d "${TMPDIR:-/tmp}/scapture-smoke.XXXXXX")
trap 'rm -rf $work' EXIT
out=build/smoke
rm -rf $out
mkdir -p $out

fail() {
  print -u2 -r -- "smoke: $*"
  exit 1
}

pixels() {
  sips -g pixelWidth -g pixelHeight $1 | awk '/pixelWidth/ { w = $2 } /pixelHeight/ { h = $2 } END { print w "x" h }'
}

# run <name style> <case id>: one app run, its state.txt in $out/<style>.txt
run() {
  local config=$work/config/scapture
  mkdir -p $config $work/root/$2
  cat > $config/config <<CONFIG
root $work/root
name $1
auto_position no
toast 0
flash no
CONFIG
  cat > $config/profiles <<PROFILES
profile as-is
app io.github.usuite.scapture
window sCapture smoke
scale 1

profile inset-2x
app io.github.usuite.scapture
window sCapture smoke
inset 28 1 1 1
scale 2
PROFILES
  print -r -- "{\"activeCase\":\"$2\",\"caseProfiles\":{}}" > $config/state.json
  XDG_CONFIG_HOME=$work/config SCAPTURE_SMOKE=$PWD/$out/$1 $app/Contents/MacOS/sCapture
  [[ -r $out/$1/state.txt ]] || fail "$1: the app wrote no state.txt"
  cp $out/$1/state.txt $out/$1.txt
}

check() {
  local style=$1 id=$2 line profile file size rest n=0
  while IFS=$'\t' read -r profile file size rest; do
    n=$((n + 1))
    [[ $file != error ]] || fail "$style $profile: $size"
    case $profile in
      as-is) [[ $size == 800x600 ]] || fail "$style as-is: $size, expected 800x600" ;;
      inset-2x) [[ $size == 1596x1142 ]] || fail "$style inset-2x: $size, expected 1596x1142" ;;
      *) fail "unexpected profile $profile" ;;
    esac
    [[ -f $work/root/$id/$file ]] || fail "$style: $file is not in the case"
    [[ $(pixels $work/root/$id/$file) == $size ]] || fail "$style: $file is $(pixels $work/root/$id/$file), the app said $size"
    print -r -- "smoke: $style $profile $file $size $rest"
  done < $out/$style.txt
  (( n == 2 )) || fail "$style: $n captures, expected 2"
}

run timestamp poc-smoke-time
check timestamp poc-smoke-time
names=($work/root/poc-smoke-time/*.png(N:t))
[[ ${names[1]} == scap-<->-<->-<->-<->.png ]] || fail "timestamp name ${names[1]}"
[[ ${names[2]} == scap-<->-<->-<->-<->(b|).png ]] || fail "timestamp name ${names[2]}"

run case-step poc-smoke-step
check case-step poc-smoke-step
names=($work/root/poc-smoke-step/*.png(N:t))
[[ $names == "poc-smoke-step-01.png poc-smoke-step-02.png" ]] || fail "case-step names $names"
[[ -z $(ls -A $work/root/poc-smoke-step | grep '^\.') ]] || fail "a temporary file was left behind"

[[ $(< $out/case-step/test.txt) == $'as-is\t800x600' ]] || fail "test capture: $(< $out/case-step/test.txt)"
print "smoke: test capture as-is 800x600, no file"

for window in settings profiles; do
  [[ -s $out/timestamp/$window.png ]] || fail "the app wrote no $window.png"
  [[ $(pixels $out/timestamp/$window.png) != 0x0 ]] || fail "$window.png is empty"
  print "smoke: $window window $(pixels $out/timestamp/$window.png)"
done
cp $work/root/poc-smoke-time/*.png $out/
print "smoke: passed, captures copied to $out"
