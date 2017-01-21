###*
 * @fileoverview 設定関係のメソッド
 ###

fs = require "fs-extra"
path = require "path"
Promise = require "promise"
os = require "os"

###*
 * 設定をおくフォルダ
 * @const
 ###
CONFIG_FOLDER_NAME = "config"
LANG_LIST = [
  "ja"
  "en"
]

ensureFile = Promise.denodeify(fs.ensureFile)
readJson = Promise.denodeify(fs.readJson)

###
 * 設定のデータ
 ###
data = {}
###
 * dataの初期値
 * @const
 ###
DEFAULT_DATA =
  repos: ["BlitzModder/BMRepository/master"]
  localRepos: []
  debugRepo: ""
  appliedMods: []
  lang: "ja"

do ->
  if os.type().includes("Windows")
    DEFAULT_DATA.blitzPath = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\World of Tanks Blitz"
  else if os.type().includes("Darwin")
    DEFAULT_DATA.blitzPath = "~/Library/Application Support/Steam/SteamApps/common/World of Tanks Blitz/World of Tanks Blitz.app/Contents/Resources/"
    # DEFAULT_DATA.blitzPath = "Applications/World of Tanks Blitz.app/Contents/Resources/"
  else
    DEFAULT_DATA.blitzPath = "World of Tanks Blitz"

###
 * エラー出力
 * @private
 ###
_outputError = (err) ->
  console.error("Error: #{err}") if err?
  return

###
 * 設定更新
 * @private
 ###
_update = ->
  fs.outputJson(path.resolve("#{CONFIG_FOLDER_NAME}/general.json"), data, _outputError)
  return

###
 * 設定をメモリに展開
 * @constructor
 ###
init = ->
  filePath = path.resolve("#{CONFIG_FOLDER_NAME}/general.json")
  return ensureFile(filePath).then( ->
    return readJson(filePath, throws: false)
  ).then( (content) ->
    data = Object.assign({}, DEFAULT_DATA)
    if content?
      data = Object.assign(data, content)
    _update()
  )

get = (a) ->
  return data[a]

set = (a, b) ->
  data[a] = b
  _update()
  return

add = (a, b) ->
  data[a].push(b)
  _update()
  return

remove = (a, b) ->
  for v, i in data[a] when JSON.stringify(v) is JSON.stringify(b)
    data[a].splice(i, 1)
  _update()
  return

reset = ->
  data = Object.assign({}, DEFAULT_DATA)
  _update()
  return

module.exports =
  LANG_LIST: LANG_LIST
  data: data
  init: init
  get: get
  set: set
  add: add
  remove: remove
  reset: reset
