path = require "path"
shell = require("electron").shell
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
  shell.openItem(path.join(config.get("blitzPath"), "wotblitz.exe"))
  return

module.exports =
  escape: escape
  openBlitz: openBlitz
