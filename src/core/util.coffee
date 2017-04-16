path = require "path"
fs = require "fs-extra"
jszip = require "jszip"
{shell} = require("electron")
os = require "os"
Promise = require "promise"
config = require "./config"

readFile = Promise.denodeify(fs.readFile)

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
    fs.statSync(path.join(require("./config").get("blitzPath"), "wotblitz.exe"))
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
  return new Promise( (resolve, reject) ->
    if useCache and _version isnt ""
      return _version
    config = require("./config")
    if config.get("blitzPathType") is "file"
      zip = new jszip()
      readFile(config.get("blitzPath")).then( (data) ->
        return zip.loadAsync(data)
      ).then( ->
        switch config.get("platform")
          when "a" then prefix = "assets"
          when "i" then prefix = "Payload/wotblitz.app"
          else prefix = ""
        file = zip.file("#{prefix}/Data/version.txt")
        if file?
          return file.async("string")
        else
          reject("Error: Version File Not Found Error")
          return
      ).then( (str) ->
        ver = _parseVersion(str)
        if ver is ""
          reject("Error: Version Regexp Error")
        else
          _version = ver
          resolve(ver)
        return
      ).catch( (err) ->
        console.log err
        reject(err)
        return
      )
      return
    readFile(path.join(config.get("blitzPath"), "Data", "version.txt"), "utf-8").then( (text) ->
      ver = _parseVersion(text)
      if ver is ""
        reject("Error: Version Regexp Error (#{text})")
      else
        _version = ver
        resolve(ver)
      return
    ).catch( ->
      return readFile(path.join(config.get("blitzPath"), "Data/version", "resources.txt"), "utf-8").then( (text) ->
        reg = /^(\d+\.\d+\.\d+)$/.exec(text)
        if reg?
          _version = ver
          resolve(reg[1])
        else
          reject("Error: Version Regexp Error (#{text})")
        return
      )
    ).catch( (err) ->
      reject(err)
      return
    )
    return
  )

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
