# lsi.nu — Nerd Font icons for Nushell's `ls`, applied as pure decoration.
# The Yazi `theme.toml` is auto-detected at `<nushell-config>/../yazi/theme.toml`
# (i.e. `~/.config/yazi/theme.toml`). Override it by setting
# `$env.LSI_THEME_PATH` before sourcing this file.

const LSI_SYMLINK = { icon: (char --unicode f0c1), fg: "#7fd0e0" }         # nf-fa-link (chain)
const LSI_SYMLINK_BROKEN = { icon: (char --unicode f127), fg: "#f44336" }  # nf-fa-chain-broken

# --- Icon theme ------------------------------------------------------------

let __lsi_theme_path = (
    $env.LSI_THEME_PATH?
    | default ($nu.default-config-dir | path dirname | path join "yazi" "theme.toml")
)

$env.LSI_THEME_PATH = $__lsi_theme_path

let __lsi_icons = if ($__lsi_theme_path | path exists) {
    let theme = (open $__lsi_theme_path)
    {
        dirs: (
            $theme.icon.dirs?
            | default []
            | reduce -f {} {|it, acc| $acc | upsert $it.name $it }
        ),
        files: (
            $theme.icon.files?
            | default []
            | reduce -f {} {|it, acc|
                $acc | upsert ($it.name | str lowercase) $it
            }
        ),
        exts: (
            $theme.icon.exts?
            | default []
            | reduce -f {} {|it, acc| $acc | upsert $it.name $it }
        ),
    }
} else {
    print --stderr $"lsi: Yazi theme not found at ($__lsi_theme_path). Set $env.LSI_THEME_PATH to your theme.toml."
    { dirs: {}, files: {}, exts: {} }
}

$env.LSI_ICONS = $__lsi_icons

def decorate-file [input] {
    let icons = $env.LSI_ICONS
    let is_record = ($input | describe | str starts-with "record")
    let path = if $is_record { $input.name } else { $input }
    let name = ($path | path basename)
    let type = if $is_record { ($input.type? | default "") } else { "" }

    # Symlinks get a chain icon (broken-chain when the target is missing),
    # never the icon of whatever they point at.
    if $type == "symlink" {
        let broken = (not ($path | path exists))
        let deco = if $broken { $LSI_SYMLINK_BROKEN } else { $LSI_SYMLINK }
        return $"(ansi $deco.fg)($deco.icon)(ansi reset) ($path)"
    }

    if $type == "dir" {
        let match = ($icons.dirs | get -o $name)
        if $match != null {
            let hex = ($match.fg? | default "#50fa7b")
            return $"(ansi $hex)($match.text)(ansi reset) ($path)"
        }
        return $"(ansi cyan)󰉋(ansi reset) ($path)"
    }

    let lname = ($name | str lowercase)
    let file_match = ($icons.files | get -o $lname)

    if $file_match != null {
        let hex = ($file_match.fg? | default "#f8f8f2")
        return $"(ansi $hex)($file_match.text)(ansi reset) ($path)"
    }

    let ext = (
        $name
        | path parse
        | get extension?
        | default ""
        | str lowercase
    )

    let ext_match = ($icons.exts | get -o $ext)
    if $ext_match != null {
        let hex = ($ext_match.fg? | default "#f8f8f2")
        return $"(ansi $hex)($ext_match.text)(ansi reset) ($path)"
    }

    $path
}

def --env __lsi_add_hook [] {
    $env.config = ($env.config | upsert hooks { default {} })

    $env.config.hooks.display_output = {||
        let val = $in
        let is_file_table = (
            (($val | describe) | str starts-with "table")
            and ("name" in ($val | columns))
            and ("type" in ($val | columns))
        )
        let out = if $is_file_table {
            $val | update name {|row| decorate-file $row }
        } else {
            $val
        }
        if (term size).columns >= 100 { $out | table -e } else { $out | table }
    }
}

__lsi_add_hook

def lsi [...args] {
    let listing = if ($args | is-empty) { ls } else { ls ...$args }
    $listing | update name {|row| decorate-file $row }
}

def decorate []: table -> table {
    update name {|row| decorate-file $row }
}
