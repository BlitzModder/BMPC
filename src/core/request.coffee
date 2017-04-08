###*
 * @fileoverview ファイルを取得するメソッド群
 ###

request = require "request"
path = require "path"
Promise = require "promise"

###*
 * リモートからファイルを取得します
 * @param {string} repoName ファイルがあるリポジトリ名
 * @param {string} fileName 取得するファイル名
 * @return {Promise}
 ###
getFromRemote = (repoName, fileName) ->
  return new Promise( (resolve, reject) ->
    names = repoName.split("/")
    if names.length < 3
      reject()
      return
    request("#{repoName}/#{fileName}", (err, res, body) ->
      if err? or (res? and res.statusCode is 404)
        reject(err)
      resolve(body)
    )
    return
  )

###
 * 詳細のURLを取得します
 * @param {Object} repo ファイルのあるリポジトリ名 {type: repoType, name: repo}
 * @param {string} id 取得するmodのid
 * @return {string}
 ###
getDetailUrl = (repo, id) ->
  switch repo.type
    when "remote"
      m = /^https?:\/\/github\.com\/(.+?)\/(.+?)\/raw\/master$/.exec(repo.name)
      if m?
        return "https://cdn.rawgit.com/#{m[1]}/#{m[2]}/master/detail/html/#{id}.html"
      return "#{repo.name}/detail/html/#{id}.html"
    when "local"
      return "file://" + path.join(repo.name, "detail/html/#{id}.html")
  return ""

###
 * 最終リリースバージョンを取得します
 * @return {Promise}
 ###
getLastestVersion = ->
  return new Promise( (resolve, reject) ->
    request(
      url: "https://api.github.com/repos/BlitzModder/BMPC/releases/latest"
      headers:
        "User-Agent": "request"
    , (err, res, body) ->
      if err? or (res? and res.statusCode is 404)
        reject(err)
      try
        response = JSON.parse(body)
        resolve(response.name)
      catch
        reject("Failed to parse JSON")
    )
    return
  )

###
 * ステータスコードを取得します
 * @param {string} url
 * @return {Number} ステータスコード
 ###
getUrlStatus = (url) ->
  return new Promise( (resolve, reject) ->
    request(url, (err, res, body) ->
      if err? and res?
        reject(err)
      else
        resolve(res.status)
      return
    )
  )

module.exports =
  getFromRemote: getFromRemote
  getDetailUrl: getDetailUrl
  getLastestVersion: getLastestVersion
  getUrlStatus: getUrlStatus
