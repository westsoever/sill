# Sourced by make-app.sh and make-client-app.sh; defines functions only.
#
# macOS keeps Screen Recording, Accessibility and the like by bundle ID plus the code's designated
# requirement. Replace an app with a build whose requirement differs (another signing identity, a
# renewed or expired certificate, ad hoc against a real one) and System Settings still shows the
# switch on, for the build before: the new one is denied and turning the switch off and on does not
# help. Resetting the bundle's rows makes macOS ask again for the new build.

# designated_requirement APP: its designated requirement, empty when it is missing or unsigned.
designated_requirement() {
    [ -e "$1" ] || return 0
    codesign -d -r- "$1" 2>&1 | sed -n 's/^# *designated => //p; s/^designated => //p' | head -1 || true
}

# reset_stale_grants BUNDLE_ID OLD_REQUIREMENT NEW_REQUIREMENT SERVICE…
# Resets each TCC service (ScreenCapture, Accessibility…) for BUNDLE_ID when the requirement
# changed, and says so. Call it only when an app was there to replace, with that app quit.
# Returns 0 when it reset them, 1 when the requirement is the same (the grants carry over).
reset_stale_grants() {
    local id="$1" old="$2" new="$3" service
    shift 3
    [ "$old" != "$new" ] || return 1
    echo "note: the signature changed since the copy this replaces, so macOS would keep its Privacy"
    echo "      grants for that one. Resetting $* for $id: allow them again once"
    echo "      (Sill.app: Settings › Permissions › Allow…)."
    echo "      was: ${old:-unsigned}"
    for service in "$@"; do
        tccutil reset "$service" "$id" >/dev/null 2>&1 || echo "warning: tccutil reset $service $id failed" >&2
    done
    return 0
}
