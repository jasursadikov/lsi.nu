# lsi.nu — Nerd Font icons for Nushell's `ls`, applied as pure decoration.
#
# Icons are added ONLY when a file listing is rendered to the terminal
# (through a `display_output` hook), so the underlying data stays clean:
#
#     ls | where name == "Hello"   # matches: `name` is exactly "Hello"
#
# Set `$env.LSI_THEME_PATH` to a Yazi `theme.toml` before sourcing this file.

# --- Icon theme ------------------------------------------------------------

let __lsi_theme_path = ($env.LSI_THEME_PATH? | default "")

let __lsi_icons = if ($__lsi_theme_path != "" and ($__lsi_theme_path | path exists)) {
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
        conds: (
            $theme.icon.conds?
            | default []
            | reduce -f {} {|it, acc| $acc | upsert $it.if $it }
        ),
    }
} else {
    print --stderr "lsi: Yazi theme not found. Set $env.LSI_THEME_PATH to your theme.toml."
    { dirs: {}, files: {}, exts: {}, conds: {} }
}

$env.LSI_ICONS = $__lsi_icons

# --- Decoration ------------------------------------------------------------
# `decorate-file` returns a DISPLAY string. It never mutates real data;
# it is only ever applied to copies produced for visualization.

def decorate-file [input] {
    let icons = $env.LSI_ICONS
    let is_record = ($input | describe | str starts-with "record")
    let path = if $is_record { $input.name } else { $input }
    let name = ($path | path basename)
    let type = if $is_record { ($input.type? | default "") } else { "" }

    # Symlinks get a link icon (orphan icon when the target is missing),
    # never the icon of whatever they point at.
    if $type == "symlink" {
        let broken = (not ($path | path exists))
        let key = if $broken { "orphan" } else { "link" }
        let match = ($icons.conds? | default {} | get -o $key)
        let hex = ($match.fg? | default "#9e9e9e")
        let glyph = ($match.text? | default "")
        return $"(ansi $hex)($glyph)(ansi reset) ($path)"
    }

    let is_dir = ($type == "dir")

    if $is_dir {
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

# --- Display-only hook -----------------------------------------------------
# Decorate file-like tables ONLY when they are being displayed. Values that
# get piped, saved, or converted never pass through this hook, so your data
# stays icon-free.

def --env __lsi_add_hook [] {
    $env.config = ($env.config | upsert hooks { default {} })

    # `display_output` must be a SINGLE closure (or string). We decorate
    # file-like tables for display, then hand off to the normal table
    # renderer. Everything else is rendered untouched.
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

# --- Opt-in decoration for pipelines --------------------------------------
# When you *do* want icons baked into a table (e.g. to pipe somewhere that
# won't trigger the display hook), use `lsi` or `| decorate`.

def lsi [...args] {
    let listing = if ($args | is-empty) { ls } else { ls ...$args }
    $listing | update name {|row| decorate-file $row }
}

def decorate []: table -> table {
    update name {|row| decorate-file $row }
}
