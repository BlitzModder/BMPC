###*
 * @fileoverview info.plistの読み込み
 ###
plist = require "plist"
request = require "./request"

###*
 * データ
 ###
data = {}

###*
 * plistを取得してパースしたものを返します
 * @param {"remote"|"local"} repoType
 * @param {string} repoName
 * @param {boolean} force キャッシュを無視して元ファイルを取得するか 既定値は"false"
 * @return {Object} plistのオブジェクト
 ###
get = (repo, force = false) ->
  {name} = repo
  if data[name]? and !force
    return data[name]
  res = await request.getWithCache(repo, "info.plist", force)
  data[name] = plist.parse(res)
  return data[name]

module.exports = {
  get
}
