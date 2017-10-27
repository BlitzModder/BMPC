###*
 * @fileoverview info.plistの読み込み
 ###
fs = require "fs-extra"
path = require "path"
plist = require "plist"
semver = require "semver"
request = require "./request"
cache = require "./cache"
config = require "./config"
util = require "./util"

###*
 * データ
 ###
data = {}

###*
 * エラー出力
 * @private
 ###
_outputError = (err) ->
  console.error("Error: #{err}") if err?
  return

###*
 * plistを取得してパースしたものを返します
 * @param {"remote"|"local"} repoType
 * @param {string} repoName
 * @param {boolean} force キャッシュを無視して元ファイルを取得するか 既定値は"false"
 * @return {Object} plistのオブジェクト
 ###
get = ({type: repoType, name: repoName}, force = false) ->
  if data[repoName]? and !force
    return data[repoName]
  isCatched = false
  try
    res = await cache.getStringFile(repoName, "info.plist", force)
  catch
    isCatched = true
    if repoType is "remote"
      content = await request.getFromRemote(repoName, "info.plist")
      res = content.toString()
    else if repoType is "local"
      res = await fs.readFile(path.join(repoName, "info.plist"), "utf8")
    else
      throw new Error()
  cache.setStringFile(repoName, "info.plist", res) if isCatched
  data[repoName] = plist.parse(res)
  return data[repoName]

module.exports =
  get: get

