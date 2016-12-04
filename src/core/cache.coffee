###*
 * @fileoverview キャッシュ関係のメソッド
 ###

fs = require "fs-extra"
path = require "path"
Promise = require "promise"

###*
 * キャッシュをおくフォルダ
 * @const
 ###
CACHE_FOLDER_NAME = "cache"

ensureFile = Promise.denodeify(fs.ensureFile)
readJson = Promise.denodeify(fs.readJson)

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
  fs.outputJson(path.resolve("#{CACHE_FOLDER_NAME}/table.json"), table, _outputError)
  return

###
 * テーブルをメモリに展開
 * @constructor
 ###
init = ->
  filePath = path.resolve("#{CACHE_FOLDER_NAME}/table.json")
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
  fs.outputFile(path.resolve("#{CACHE_FOLDER_NAME}/#{num}.txt"), fileContent, callback)
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
    fs.readFile(path.resolve("#{CACHE_FOLDER_NAME}/#{num}.txt"), "utf8", (err, content) ->
      if err?
        reject(err)
        return
      resolve(content)
      return
    )
  )

module.exports =
  init: init
  setStringFile: setStringFile
  getStringFile: getStringFile
