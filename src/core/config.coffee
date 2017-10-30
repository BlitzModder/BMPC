###*
 * @fileoverview 設定関係のメソッド
 ###

fs = require "fs-extra"
path = require "path"
{app} = require "electron"
util = require "./util"
os = require "os"

###*
 * 設定をおくフォルダ
 * @const
 ###
CONFIG_FOLDER_PATH = path.join(app.getPath("userData"), "config")
GENERAL_CONFIG_PATH = path.join(CONFIG_FOLDER_PATH, "general.json")
LANG_LIST = [
  "ja"
  "en"
  "ru"
  "zh_TW"
  "zh_CN"
]
PLATFORM_LIST = [
  "w"
  "m"
  "a"
  "i"
]
BLITZ_PATH =
  WIN64: "C:\\Program Files (x86)\\Steam\\steamapps\\common\\World of Tanks Blitz"
  WIN32: "C:\\Program Files\\Steam\\steamapps\\common\\World of Tanks Blitz"
  MACSTEAM: path.join(os.homedir(), "Library/Application Support/Steam/SteamApps/common/World of Tanks Blitz/World of Tanks Blitz.app/Contents/Resources/")
  MACSTORE: "/Applications/World of Tanks Blitz.app/Contents/Resources/"

###
 * 設定のデータ
 ###
data = {}
###
 * dataの初期値
 * @const
 ###
DEFAULT_DATA =
  repos: ["http://subdiox.com/repo"]
  localRepos: []
  debugRepo: ""
  appliedMods: []
  lang: "ja"
  blitzPathType: "folder"

getDefaultWinBlitzPath = ->
  switch os.arch()
    when "x64" then return BLITZ_PATH.WIN64
    when "ia32" then return BLITZ_PATH.WIN32

do ->
  DEFAULT_DATA.platform = util.getPlatform()
  switch DEFAULT_DATA.platform
    when "w"
      DEFAULT_DATA.blitzPath = getDefaultWinBlitzPath()
      DEFAULT_DATA.blitzPathRadio = "win"
    when "m"
      DEFAULT_DATA.blitzPath = BLITZ_PATH.MACSTEAM
      DEFAULT_DATA.blitzPathRadio = "macsteam"
    else
      DEFAULT_DATA.blitzPath = "World of Tanks Blitz"
      DEFAULT_DATA.blitzPathRadio = "other"
  return


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
  try
    await fs.outputJson(GENERAL_CONFIG_PATH, data)
  catch err
    _outputError(err)
  return

###
 * 設定をメモリに展開
 * @constructor
 ###
init = ->
  await fs.ensureFile(GENERAL_CONFIG_PATH)
  data = Object.assign({}, DEFAULT_DATA)
  try
    content = await fs.readJson(GENERAL_CONFIG_PATH, throws: false)
  catch err
    _outputError(err)
  if content?
    data = Object.assign(data, content)
  else
    machineLang = app.getLocale()
    data.lang =
      if machineLang is ["ja", "ru", "zh-TW", "zh-CN"]
        machineLang
      else if machineLang.includes("en")
        "en"
      else if machineLang.includes("zh")
        "zh_CN"
      else
        "en"
  _update()
  return

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

module.exports = {
  GENERAL_CONFIG_PATH
  LANG_LIST
  PLATFORM_LIST
  BLITZ_PATH
  getDefaultWinBlitzPath
  data
  init
  get
  set
  add
  remove
  reset
}
