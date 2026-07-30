return {
    settings = {
        cargo = {
            allFeatures = true,
            allTargets = true,
            loadOutDirsFromCheck = true,
            buildScripts = {
                enable = true,
            },
        },
        checkOnSave = {
            allFeatures = true,
            command = "clippy",
        }
    }
}
