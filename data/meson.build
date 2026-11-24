legacy_css = custom_target(
    'legacy-css',
    input: files(
        'css/style.css',
        'css/steamos.css',
        'css/oled.css',
        'css/breeze-dark.css',
        'css/breeze-light.css',
    ),
    output: [
        'style-legacy.css',
        'steamos-legacy.css',
        'oled-legacy.css',
        'breeze-dark-legacy.css',
        'breeze-light-legacy.css',
    ],
    command: [
        find_program('python3'),
        files('css/legacy-colors.py'),
        '@OUTDIR@',
        '@INPUT@',
    ],
)

resources = gnome.compile_resources(
    'resources',
    'com.vysp3r.ProtonPlus.gresource.xml',
    source_dir: [meson.current_build_dir(), meson.current_source_dir()],
    dependencies: legacy_css,
)

install_subdir(
    'icons/hicolor',
    install_dir: get_option('prefix') / get_option('datadir') / 'icons',
    strip_directory: false,
)

desktop_file = i18n.merge_file(
    input: 'com.vysp3r.ProtonPlus.desktop.in',
    output: 'com.vysp3r.ProtonPlus.desktop',
    type: 'desktop',
    po_dir: '../po',
    install: true,
    install_dir: get_option('datadir') / 'applications',
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
    test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

# Keep AppStream metadata in its source language instead of merging gettext
# catalogs into the installed document.
appstream_file = files('com.vysp3r.ProtonPlus.metainfo.xml.in')
install_data(
    appstream_file,
    rename: 'com.vysp3r.ProtonPlus.metainfo.xml',
    install_dir: get_option('datadir') / 'metainfo',
)

appstream_cli = find_program('appstreamcli', required: false)
if appstream_cli.found()
    test(
        'Validate appstream file',
        find_program('sh'),
        args: [files('../packaging/validate-appstream.sh'), appstream_cli.full_path(), appstream_file],
    )
else
    appstream_util = find_program('appstream-util', required: false)
    if appstream_util.found()
        test(
            'Validate appstream file',
            appstream_util,
            args: ['validate-relax', '--nonet', appstream_file],
        )
    endif
endif

install_data(
    'com.vysp3r.ProtonPlus.gschema.xml',
    install_dir: get_option('datadir') / 'glib-2.0/schemas',
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
    test(
        'Validate schema file',
        compile_schemas,
        args: ['--strict', '--dry-run', meson.current_source_dir()],
    )
endif
