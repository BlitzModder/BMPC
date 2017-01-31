###*
 * @fileoverview ファイルを取得するメソッド群
 ###

fetch = require "fetch"
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
    fetch.fetchUrl("#{repoName}/#{fileName}", (err, meta, body) ->
      if err? or meta.status is 404
        reject(err)
      resolve(body)
    )
    return
  )

###
 * 詳細のURLを取得します
 * @param {Object} repo ファイルのあるリポジトリ名 {type: repoType, name: repo}
 * @param {string} id 取得するmodのid
 * @param {string} lang 言語
 * @return {string}
 ###
getDetailUrl = (repo, id, lang) ->
  switch repo.type
    when "remote"
      names = repo.name.split("/")
      return "#{repo.name}/Detail/#{lang}/#{id}.html"
    when "local"
      return "file://" + path.join(repo.name, "Detail", lang, "#{id}.html")
  return ""

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
  getFromRemote: getFromRemote
  getDetailUrl: getDetailUrl
  getLastestVersion: getLastestVersion
