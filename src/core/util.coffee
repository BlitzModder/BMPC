path = require "path"
fs = require "fs-extra"
jszip = require "jszip"
{shell} = require("electron")
os = require "os"
config = require "./config"

###*
 * HTMLエスケープ
 ###
escape = (str) ->
  return str.replace(/[&'`"<>]/g, (match) ->
    return {
      "&": "&amp;"
      "'": "&#x27;"
      "`": "&#x60;"
      "\"": "&quot;"
      "<": "&lt;"
      ">": "&gt;"
    }[match]
  )

###*
 * Blitzを実行します
 ###
openBlitz = ->
  shell.openItem(path.join(require("./config").get("blitzPath"), "wotblitz.exe"))
  return

###*
 * Blitzが存在するか判定します
 ###
blitzExists = ->
  try
    await fs.stat(path.join(require("./config").get("blitzPath"), "wotblitz.exe"))
    return true
  catch
    return false

_parseVersion = (str) ->
  reg = /_(\d+\.\d+\.\d+)_/.exec(str)
  if reg?
    return reg[1]
  else
    reg = /^(\d+\.\d+)\.(\d+)\.(\d+)_/.exec(str)
    if reg?
      if reg[2] < 10
        return reg[1]+"."+reg[2]
      else if reg[3] < 10
        return reg[1]+"."+reg[3]
      else
        return reg[1]+".0"
    else
      reg = /^\d+\.\d+/.exec(str)
      if reg?
        return reg[0]+".0"
  return ""

_version = ""
###*
 * Blitzのバージョンを取得します
 ###
getVersion = (useCache = false) ->
  if useCache and _version isnt ""
    return _version
  config = require("./config")
  if config.get("blitzPathType") is "file"
    zip = new jszip()
    data = await fs.readFile(config.get("blitzPath"))
    await zip.loadAsync(data)
    switch config.get("platform")
      when "a" then prefix = "assets"
      when "i" then prefix = "Payload/wotblitz.app"
      else prefix = ""
    file = zip.file("#{prefix}/Data/version.txt")
    if !file?
      throw new Error("Error: Version File Not Found Error")
    str = await file.async("string")
    ver = _parseVersion(str)
    if ver is ""
      throw new Error("Error: Version Regexp Error")
    _version = ver
    return ver
  try
    text = await fs.readFile(path.join(config.get("blitzPath"), "Data", "version.txt"), "utf-8")
    ver = _parseVersion(text)
    if ver is ""
      throw new Error("Error: Version Regexp Error (#{text})")
    _version = ver
    return ver
  catch
    text = await fs.readFile(path.join(config.get("blitzPath"), "Data/version", "resources.txt"), "utf-8")
    reg = /^(\d+\.\d+\.\d+)$/.exec(text)
    if !reg?
      throw new Error("Error: Version Regexp Error (#{text})")
    _version = ver
    return reg[1]
  return

###*
 * 利用している端末を取得します
 ###
getPlatform = ->
  return "w" if os.type().includes("Windows")
  return "m" if os.type().includes("Darwin")
  return "w"

###*
 * ディレクトリか判断します
 ###
isDirectory = (topath) ->
  try
    return fs.statSync(topath).isDirectory()
  catch
    return false

###*
 * ファイルか判断します
 ###
isFile = (topath) ->
  try
    return fs.statSync(topath).isFile()
  catch
    return false

module.exports =
  escape: escape
  openBlitz: openBlitz
  blitzExists: blitzExists
  getVersion: getVersion
  getPlatform: getPlatform
  isDirectory: isDirectory
  isFile: isFile
