def main [] {
    let here = ($env.FILE_PWD? | default (pwd))
    let src = ($here | path join "lsi.nu")

    if not ($src | path exists) {
        print --stderr $"install: could not find lsi.nu next to the installer \(($src)\)."
        exit 1
    }

    let config_dir = $nu.default-config-dir
    let dest = ($config_dir | path join "lsi.nu")
    let config_file = $nu.config-path
    let source_line = $'source "($dest)"'

    mkdir $config_dir
    cp $src $dest
    print $"install: copied lsi.nu -> ($dest)"

    # Add the source line to config.nu, but never twice.
    let already_sourced = (
        ($config_file | path exists)
        and (
            open $config_file
            | lines
            | any {|line|
                ($line | str trim | str starts-with "source") and ($line | str contains "lsi.nu")
            }
        )
    )

    if $already_sourced {
        print "install: config.nu already sources lsi.nu — skipping."
    } else {
        $"\n# lsi.nu — Nerd Font icons for `ls`\n($source_line)\n" | save --append $config_file
        print $"install: appended `($source_line)` to ($config_file)"
    }

    # lsi.nu reads a Yazi theme.toml; warn early if it is missing.
    let theme = (
        $env.LSI_THEME_PATH?
        | default ($config_dir | path dirname | path join "yazi" "theme.toml")
    )

    if not ($theme | path exists) {
        print --stderr $"install: note — Yazi theme not found at ($theme)."
        print --stderr "install: files use fallback icons until it exists; set $env.LSI_THEME_PATH to override."
    }

    print ""
    print "install: done. Restart Nushell, or load it now with:"
    print $"    source \"($dest)\""
}
