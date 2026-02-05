# quiet the linter who thinks .nims is the same as .nim...
when declared(task):
  import std/[sequtils, sugar, strutils, strformat, os]

  switch("outdir", "out")
  switch("path", "../..")
  switch("hints", "off")

  

  proc getFilesWithEnding(folder: string, fileEnding: string, exclude: seq[string]): seq[string] {.compileTime.} =
    result = collect:
      for path in walkDirRec(folder):
        if path.extractFilename() in exclude:
          continue
        if path.endswith(fileEnding): path


  task test, "Run all Nim tests in this directory":
    let testFiles = getFilesWithEnding(".", ".nim", @["test_common.nim"])
    for testFile in testFiles:
      echo fmt("Running test: {testFile}...")
      exec fmt("nim c -r {testFile}")
