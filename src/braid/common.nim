#common.nim

import os, strutils, osproc

# const respath* = "../res" / hostCPU / hostOS
const configFolderName = ".refaqtory"
const workTag* = "work"

proc getPath*(rp: string) : string =
    discard rp.existsOrCreateDir
    assert existsDir rp
    return rp

proc configPath*() : string =
    return getPath(unixToNativePath getHomeDir() / configFolderName)
    
proc projectPath*(project: string) : string =
    return getPath(configPath() / project)
    
proc workPath*(project: string) : string =
    return getPath(project.projectPath() / workTag)



#--- DISPLAY LEVEL

var displayLevel: int
# error = 0, state = 1, activity = 2, debug = 3
proc setDisplay*(display = 1) =
    displayLevel=display

proc see*(level = 0, message: string) =
    if level <= displayLevel:
        echo message
    if displayLevel > 3:
        var log: File
        if log.open(configPath()/"see.log", fmAppend):
            log.writeLine(message)
        defer:
            log.close()

proc runProcess*(cmd: string; wrkdir: string = ""): TaintedString  =
    4.see "run cmd : " & cmd
    let mycurdir = getCurrentDir()
    if wrkdir != "":
        setCurrentDir wrkdir
    result = execProcess cmd
    setCurrentDir mycurdir
    return result

#--- VERSIONS
type #hold related build version info
    ConstVersion* = object
        name,tag,date,time,vcs,extra: string

proc newConstVersion*(name, tag, date="", time="", vcs="", extra=""): ConstVersion =
    ConstVersion(name:name, tag:tag, date:date, time:time, vcs:vcs, extra:extra);
        
type
    Version = tuple[name,tag,date,time,vcs,extra: string]

proc newVersion*(ver: ConstVersion): Version =
    result = (name:ver.name,
    tag:ver.tag,
    date:ver.date, 
    time:ver.time, 
    vcs:ver.vcs, 
    extra:ver.extra)

type
    Versions* = seq[Version]

# const VcsInfo = staticExec("git rev-parse HEAD")
const VcsInfo = staticExec("fossil info").split("checkout:")[1].strip()
const thisVersion* = newConstVersion(
    name=getAppFilename(),
    tag="0.0.0",
    date=CompileDate,
    time=CompileTime,
    vcs=VcsInfo[0..7],
    extra="nim ver: " & NimVersion)

proc newVersions*(): Versions =
    result = @[newVersion(thisVersion)]

var exeVersions* = newVersions()

when isMainModule:
    #mynimall.nim
    # /****************************************************************************
    # * This Source Code Form is subject to the terms of the Mozilla Public
    # * License, v. 2.0. If a copy of the MPL was not distributed with this file,
    # * You can obtain one at http://mozilla.org/MPL/2.0/.
    # *
    # * Copyright (c) 2016, shannon.mackey@refaqtory.com
    # * ***************************************************************************/

    let doc = """
    exename.

    exe short desc

    exe long desc

    Usage:
    exename [optionA | optionB ]  <required arg> [--user=<user>] [--password=<password>] [--server=<url>] [--debug=<display>] 
    exename (-h | --help)
    exename --version

    Options:
    -u --user=<user>            User to setup account when serving, or access server when working.
    -p --password=<password>    Password to setup account when serving, or access server when working.
    -s --server=<url>           Server <url>. Only first use requires <user> & <password> also.
    -d --debug=<display>        Set <display> level [default: 1].   
    -h --help                   Show this screen.
    --version                   Show version.
    
    """

    #TODO: put the actual version data in the help string during compile

    # import strutils
    import docopt
    
    let args = docopt(doc, version = versionTag)
    setDisplay(parseInt($args["--debug"]))
    let proj = $args["<project>"]
    let url = $args["--server"]
    let user = $args["--user"]
    let password = $args["--password"]
    var processor: Core
    if args["new"] or args["join"]:
        5.see ">>>> initialize new project"
        processor = initCore(if args["serve"]:
                                    Mode.Serve
                                else:
                                    Mode.Work,
                                proj,
                                url,
                                user,
                                password)
        # elif args["next"]:

