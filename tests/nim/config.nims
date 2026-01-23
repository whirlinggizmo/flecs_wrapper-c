when declared(task):
    import os
    import strformat
    import strutils

    let thisDir = currentSourcePath().parentDir() 
    var basePath = joinPath(thisDir, "..", "..")
    normalizePath(basePath)
    #echo fmt"Base path: {basePath}"

    switch("path", "tests/nim/config.nims")
    switch("path", "bindings/nim")
    switch("path", basePath)
    switch("hints", "off")
    #switch("verbosity", "2")

    proc createTempDir():string =
        result = joinPath(basePath, "temp")
        if not dirExists(result):
            mkDir(result)

    proc runTest(testFile: string) : int =
        let tempDir = createTempDir()
        var cmd = ["nim", "c", "-r", "--outdir:" & tempDir, joinPath(basePath, testFile)].join(" ")
        let cmdResult = gorgeEx(cmd)
        if cmdResult.exitCode != 0:
            echo testFile & ": FAILED: " & cmdResult.output
        else:
            echo testFile & ": PASSED"
        result = cmdResult.exitCode

    task test, "Run Nim tests":
        let tests = [
            "tests/nim/test_add_components.nim",
            "tests/nim/test_remove_components.nim",
            "tests/nim/test_systems.nim",
            "tests/nim/test_observers.nim",        ]
        var totalFailures = 0
        for testFile in tests:
            totalFailures += runTest(testFile)
        if totalFailures == 0:
            echo "All tests passed!"
        else:
            echo fmt"{totalFailures} tests failed."
            quit(1)
