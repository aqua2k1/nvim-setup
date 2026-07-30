return {
    cmd = {
        'clangd',
        '--background-index',
        '--header-insertion-decorators=true',
    },
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
    init_options = {
        fallbackFlags = {
            vim.bo.filetype == 'cpp' and '--std=c++20' or nil,
        },
    },
    root_markers = {
        "compile_commands.json",
        "compile_flags.txt",
        "configure.ac", -- AutoTools
        "Makefile",
        "configure.ac",
        "configure.in",
        "config.h.in",
        "meson.build",
        "meson_options.txt",
        "build.ninja",
        ".git",
    },
}
