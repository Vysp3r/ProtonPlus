sources = files(
    'main.vala',
    'globals.vala',
    'return-code.vala',
)

subdir('cli')
subdir('widgets')
subdir('models')
subdir('vdf')
subdir('utils')

deps = [
    config_dep,
    dependency('gtk4'),
    dependency('glib-2.0'),
    dependency('libadwaita-1', version : '>= 1.6'),
    dependency('json-glib-1.0'),
    dependency('libsoup-3.0'),
    dependency('gee-0.8'),
    dependency('libarchive'),
    meson.get_compiler('c').find_library('m', required : false),
    sdl3_dep,
]

executable(
    meson.project_name().split('.')[2].to_lower(),
    resources,
    sources,
    dependencies : deps,
    include_directories : config_inc,
    install : true
)
