path = require "path"
fs = require "fs-extra"
shell = require("electron").shell
os = require "os"
Promise = require "promise"

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
  shell.openItem(path.join(config.get("blitzPath"), "wotblitz.exe"))
  return

###*
 * Blitzのバージョンを取得します
 ###
getVersion = ->
  return new Promise( (resolve, reject) ->
    readFile(path.join(require("./config").get("blitzPath"), "Data", "version.txt"), "utf-8").then( (text) ->
      reg = /_(\d+\.\d+\.\d+)_/.exec(text)
      if reg?
        resolve(reg[1])
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

module.exports =
  escape: escape
  openBlitz: openBlitz
  getVersion: getVersion
  getPlatform: getPlatform
