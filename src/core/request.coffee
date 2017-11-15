###*
 * @fileoverview ファイルを取得するメソッド群
 ###

requestP = require "request-promise-native"
path = require "path"
fs = require "fs-extra"
cache = require "./cache"
util = require "./util"

###*
 * リモートからファイルを取得します
 * @param {string} repoName ファイルがあるリポジトリ名
 * @param {string} fileName 取得するファイル名
 * @return {Promise}
 ###
getFromRemote = (repoName, fileName) ->
  names = repoName.split("/")
  if names.length < 3
    throw new Error("不明なリモートリポジトリ名")
  return await requestP("#{repoName}/#{fileName}")

###*
 * ファイルを取得します
 * @param {Object} repo ファイルのあるリポジトリ名 {type: repoType, name: repo}
 * @param {string} fileName 取得するファイル名
 * @return {Promise}
 ###
get = ({name, type}, fileName) ->
  if type is "remote"
    content = await getFromRemote(name, fileName)
    res = content.toString()
  else if type is "local"
    res = await fs.readFile(path.join(name, fileName), "utf8")
  else
    throw new Error("不明なレポジトリ形式")
  return res

###*
 * キャッシュを活用してファイルを取得します
 * @param {Object} repo ファイルのあるリポジトリ名 {type: repoType, name: repo}
 * @param {string} fileName 取得するファイル名
 * @param {boolean} force キャッシュを利用しない
 * @return {Promise}
 ###
getWithCache = (repo, fileName, force) ->
  try
    res = await cache.getStringFile(repo.name, fileName, force)
  catch
    res = await get(repo, fileName)
    cache.setStringFile(repo.name, fileName, res)
  return res

###
 * 詳細のURLを取得します
 * @param {Object} repo ファイルのあるリポジトリ名 {type: repoType, name: repo}
 * @param {string} id 取得するmodのid
 * @return {string}
 ###
getDetailUrl = ({name, type}, id) ->
  switch type
    when "remote"
      m = /^https?:\/\/github\.com\/(.+?)\/(.+?)\/raw\/master$/.exec(name)
      if m?
        return "https://cdn.rawgit.com/#{m[1]}/#{m[2]}/master/detail/html/#{id}.html"
      return "#{name}/detail/html/#{id}.html"
    when "local"
      return "file://" + path.join(name, "detail/html/#{id}.html")
  return ""

###
 * changelogを取得します
 * @param {Object} repo ファイルのあるリポジトリ名 {type: repoType, name: repo}
 * @return {string}
 ###
getChangelog = ({name, type}) ->
  switch type
    when "remote"
      m = /^https?:\/\/github\.com\/(.+?)\/(.+?)\/raw\/master$/.exec(name)
      if m?
        url = "https://cdn.rawgit.com/#{m[1]}/#{m[2]}/master/changelog.txt"
      else
        url = "#{name}/changelog.txt"
      try
        return await requestP(url)
    when "local"
      try
        return await fs.readFile(path.join(name, "changelog.txt"), "utf8")
  return ""

###
 * 最終リリースバージョンを取得します
 * @return {Promise}
 ###
getLastestVersion = ->
  body = await requestP(
    url: "https://api.github.com/repos/BlitzModder/BMPC/releases/latest"
    headers:
      "User-Agent": "request"
  )
  try
    {name, tag_name} = JSON.parse(body)
    ver = name
    ver = tag_name if ver is ""
  catch err
    throw new Error("Failed to parse JSON(#{err})")
  return ver

###
 * ステータスコードを取得します
 * @param {string} url
 * @return {Number} ステータスコード
 ###
getUrlStatus = (url) ->
  try
    {statusCode} = await requestP({url, resolveWithFullResponse: true})
  catch
    statusCode = if util.isFile(url) then 200 else 404
  return statusCode

module.exports = {
  getFromRemote
  get
  getWithCache
  getChangelog
  getDetailUrl
  getLastestVersion
  getUrlStatus
}
