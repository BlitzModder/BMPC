###*
 * @fileoverview ファイルを取得するメソッド群
 ###

fetch = require "fetch"
Promise = require "promise"

###*
 * GitHubからファイルを取得します
 * @param {string} repoName ファイルがあるリポジトリ名
 *     「ユーザー名/レポジトリ名/ブランチ名」の形式。
 * @param {string} fileName 取得するファイル名
 * @return {Promise}
 ###
getFromGitHub = (repoName, fileName) ->
  return new Promise( (resolve, reject) ->
    names = repoName.split("/")
    if names.length < 3
      reject()
      return
    fetch.fetchUrl("https://raw.githubusercontent.com/#{names[0]}/#{names[1]}/#{names[2]}/#{fileName}", (err, meta, body) ->
      if err? or meta.status is 404
        reject(err)
      resolve(body)
    )
    return
  )

###
 * 最終リリースバージョンを取得します
 * @return {Promise}
 ###
getLastestVersion = ->
  return new Promise( (resolve, reject) ->
    fetch.fetchUrl("https://api.github.com/repos/BlitzModder/BMPC/releases/latest", (err, meta, body) ->
      if err? or meta.status is 404
        reject(err)
      resolve(JSON.parse(body).name)
    )
    return
  )

module.exports =
  getFromGitHub: getFromGitHub
  getLastestVersion: getLastestVersion
