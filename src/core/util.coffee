path = require "path"
fs = require "fs-extra"
shell = require("electron").shell
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

###*
 * Blitzのバージョンを取得します
 ###
getVersion = ->
  return new Promise( (resolve, reject) ->
    if require("./config").get("blitzPathType") is "file"
      reject()
      return
    readFile(path.join(require("./config").get("blitzPath"), "Data", "version.txt"), "utf-8").then( (text) ->
      reg = /_(\d+\.\d+\.\d+)_/.exec(text)
      if reg?
        resolve(reg[1])
      else
        reg = /^(\d+\.\d+)\.(\d+)\.(\d+)_/.exec(text)
        if reg?
          if reg[2] < 10
            resolve(reg[1]+"."+reg[2])
          else if reg[3] < 10
            resolve(reg[1]+"."+reg[3])
          else
            resolve(reg[1]+".0")
        else
          reject("Error: Version Regexp Error (#{text})")
      return
    ).catch( ->
      return readFile(path.join(require("./config").get("blitzPath"), "Data/version", "resources.txt"), "utf-8").then( (text) ->
        reg = /^(\d+\.\d+\.\d+)$/.exec(text)
        if reg?
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
