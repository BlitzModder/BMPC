###*
 * @fileoverview キャッシュ関係のメソッド
 ###

fs = require "fs-extra"
path = require "path"
{app} = require "electron"
denodeify = require "denodeify"

###*
 * キャッシュをおくフォルダ
 * @const
 ###
CACHE_FOLDER_PATH = path.join(app.getPath("userData"), "plistCache")

ensureFile = denodeify(fs.ensureFile)
readJson = denodeify(fs.readJson)
remove = denodeify(fs.remove)

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
  fs.outputJson(path.join(CACHE_FOLDER_PATH,"table.json"), table, _outputError)
  return

###
 * テーブルをメモリに展開
 * @constructor
 ###
init = ->
  filePath = path.join(CACHE_FOLDER_PATH,"table.json")
  return ensureFile(filePath).then( ->
    return readJson(filePath, throws: false)
  ).then( (content) ->
    table = if content? then content else DEFAULT_DATA
    _update()
  )

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
  fs.outputFile(path.join(CACHE_FOLDER_PATH,"#{num}.txt"), fileContent, callback)
  return

###
 * キャッシュを取得
 ###
getStringFile = (repoName, fileName, force = false) ->
  num = get("#{repoName}/#{fileName}")
  return new Promise( (resolve, reject) ->
    if force
      reject()
      return
    fs.readFile(path.join(CACHE_FOLDER_PATH,"#{num}.txt"), "utf8", (err, content) ->
      if err?
        reject(err)
        return
      resolve(content)
      return
    )
  )

clear = ->
  return remove(CACHE_FOLDER_PATH)

module.exports =
  init: init
  setStringFile: setStringFile
  getStringFile: getStringFile
  clear: clear
