sources = files(
    'return-code.vala',
    'globals.vala',
)

subdir('cli')
subdir('controller')
subdir('launch-options')
subdir('widgets')
subdir('models')
subdir('providers')
subdir('services')
subdir('utils')

sources_app = files(
    'main.vala',
)

deps = [
    config_dep,
    dependency('gtk4', version : '>= 4.14'),
    dependency('glib-2.0'),
    dependency('gio-unix-2.0'),
    dependency('libadwaita-1', version : '>= 1.5'),
    dependency('json-glib-1.0'),
    dependency('libsoup-3.0'),
    dependency('gee-0.8'),
    dependency('libarchive'),
    dependency('cairo'),
    meson.get_compiler('c').find_library('m'),
    sdl3_dep,
]

protonplus_lib = static_library(
    'protonplus_core',
    sources,
    dependencies : deps,
    include_directories : config_inc,
    install : false
)

executable(
    meson.project_name().split('.')[2].to_lower(),
    sources_app,
    dependencies : deps + [resources_dep],
    link_with: protonplus_lib,
    include_directories : config_inc,
    install : true
)
