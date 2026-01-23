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

    proc runTest(testFile: string) : int =
        var testFile = testFile
        if  testFile.len == 0:
            testFile = "<unknown>"
        let buildRootDir = joinPath(basePath, "build")
        let buildDir = joinPath(buildRootDir, splitPath(testFile).head)
        let testFilePath = joinPath(basePath, testFile)
        if not fileExists(testFilePath):
            echo testFile & ": FAILED (file not found)"
            return -1
        var cmd = ["nim", "c", "-r", "--outDir:" & buildDir, joinPath(basePath, testFile)].join(" ")
        let cmdResult = gorgeEx(cmd)
        if cmdResult.exitCode != 0:
            echo testFile & ": FAILED: " & cmdResult.output
        else:
            echo testFile & ": PASSED"
        result = cmdResult.exitCode

    task test, "Run Nim tests":
        let tests = [
            "",
            "tests/nim/test_flecs.nim",
            "tests/nim/test_components.nim",
            "tests/nim/test_entities.nim",
            "tests/nim/test_systems.nim",
            "tests/nim/test_observers.nim",
        ]
        var totalFailures = 0
        for testFile in tests:
            if runTest(testFile) != 0:
                totalFailures+=1
        if totalFailures == 0:
            echo "All tests passed!"
        else:
            echo fmt"{totalFailures} tests failed."
            quit(1)
