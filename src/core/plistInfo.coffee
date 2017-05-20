###*
 * @fileoverview info.plistの読み込み
 ###
fs = require "fs-extra"
path = require "path"
plist = require "plist"
Promise = require "promise"
semver = require "semver"
request = require "./request"
cache = require "./cache"
config = require "./config"
util = require "./util"

readFile = Promise.denodeify(fs.readFile)

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
  return new Promise( (resolve, reject) ->
    if data[repoName]? and !force
      resolve(data[repoName])
      return
    isCatched = false
    cache.getStringFile(repoName, "info.plist", force).catch( ->
      isCatched = true
      if repoType is "remote"
        return request.getFromRemote(repoName, "info.plist").then( (content) ->
          return content.toString()
        )
      else if repoType is "local"
        return readFile(path.join(repoName, "info.plist"), "utf8")
      return Promise.reject()
    ).then( (res) ->
      cache.setStringFile(repoName, "info.plist", res) if isCatched
      data[repoName] = plist.parse(res)
      resolve(data[repoName])
      return
    ).catch( (err) ->
      reject(err)
      return
    )
  )

module.exports =
  get: get

