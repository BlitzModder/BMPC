###*
 * @fileoverview キャッシュ関係のメソッド
 ###

fs = require "fs-extra"
path = require "path"
{app} = require "electron"

###*
 * キャッシュをおくフォルダ
 * @const
 ###
CACHE_FOLDER_PATH = path.join(app.getPath("userData"), "plistCache")

###
 * キャッシュファイルと実際のファイルのテーブル
 ###
table = {}
###
 * tableの初期値
 * @const
 ###
DEFAULT_DATA =
  length: 0

###
 * エラー出力
 * @private
 ###
_outputError = (err) ->
  console.error("Error: #{err}") if err?
  return

###
 * テーブル更新
 * @private
 ###
_update = ->
  try
    await fs.outputJson(path.join(CACHE_FOLDER_PATH,"table.json"), table)
  catch err
    _outputError(err)
  return

###
 * テーブルをメモリに展開
 * @constructor
 ###
init = ->
  filePath = path.join(CACHE_FOLDER_PATH,"table.json")
  await fs.ensureFile(filePath)
  try
    content = await fs.readJson(filePath, throws: false)
    table = if content? then content else DEFAULT_DATA
  catch err
    table = DEFAULT_DATA
    _outputError(err)
  _update()
  return

###
 * キャッシュ名を取得
 ###
get = (key) ->
  return table[key]

###
 * キャッシュ名を追加
 ###
add = (key) ->
  if get(key)?
    return get(key)
  num = table.length++
  _update()
  return num

###
 * キャッシュを追加
 ###
setStringFile = (repoName, fileName, fileContent, callback = _outputError) ->
  num = add("#{repoName}/#{fileName}")
  table["#{repoName}/#{fileName}"] = num
  try
    await fs.outputFile(path.join(CACHE_FOLDER_PATH,"#{num}.txt"), fileContent)
  catch
    callback()
  return

###
 * キャッシュを取得
 ###
getStringFile = (repoName, fileName, force = false) ->
  num = get("#{repoName}/#{fileName}")
  if force
    throw new Error("キャッシュを無視")
  return await fs.readFile(path.join(CACHE_FOLDER_PATH,"#{num}.txt"), "utf8")

clear = ->
  return fs.remove(CACHE_FOLDER_PATH)

module.exports = {
  init
  setStringFile
  getStringFile
  clear
}
