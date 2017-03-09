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
    cache.getStringFile(repoName, "info.plist", force).then( (content) ->
      data[repoName] = plist.parse(content)
      resolve(data[repoName])
      return
    , (err) ->
      if repoType is "remote"
        request.getFromRemote(repoName, "info.plist").then( (content) ->
          string = content.toString()
          cache.setStringFile(repoName, "info.plist", string)
          data[repoName] = plist.parse(string)
          resolve(data[repoName])
          return
        , (err) ->
          reject(err)
          return
        )
      else if repoType is "local"
        readFile(path.join(repoName, "info.plist"), "utf8").then( (res) ->
          cache.setStringFile(repoName, "info.plist", res)
          data[repoName] = plist.parse(res)
          resolve(data[repoName])
          return
        , (err) ->
          reject(err)
          return
        )
      else
        reject()
      return
    )
  )

module.exports =
  get: get

