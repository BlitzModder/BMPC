###*
 * @fileoverview MODを適応/解除するメソッド群
 ###

{app} = require "electron"
path = require "path"
fs = require "fs-extra"
fstream = require "fstream"
jszip = require "jszip"
readdirp = require "readdirp"
request = require "request"
unzip = require "unzipper"
config = require "./config"
util = require "./util"

TEMP_FOLDER = path.join(app.getPath("temp"), "BlitzModderPC")

###*
 * リモートからとってくる
 ###
_getFromRemote = (folder, mod, log) ->
  log("download")
  return request("#{mod.repo.name}/#{folder}/#{mod.name}.zip")
    .on("response", ->
      log("downloaded")
      log("zipextract")
    )
    .pipe(
      unzip.Parse()
        .on("end", ->
          log("zipextracted")
        )
    )

###*
 * ローカルからとってくる
 ###
_getFromLocal = (folder, mod, log) ->
  dirpath = path.join(mod.repo.name, folder, mod.name)
  zippath = path.join(mod.repo.name, folder, mod.name + ".zip")
  if util.isDirectory(dirpath)
    log("copydir")
    return readdirp(root: dirpath)
  else if util.isFile(zippath)
    log("zipextract")
    return fs.createReadStream(zippath).pipe(unzip.Parse())
  return

###*
 * dataイベントから適応する
 *###
_applyFromData = (outputFolder, {path: pa, fullPath}, pathList, cb) ->
  return new Promise( (resolve, reject) ->
    pathList.add(pa)
    fstream
      .Reader(fullPath)
      .pipe(fstream.Writer(path.join(outputFolder, pa)))
      .on("err", (err) ->
        reject(err)
        return
      )
      .on("close", ->
        resolve(pa)
        return
      )
    return
  )

###*
 * entryイベントから適応する
 *###
_applyFromEntry = (outputFolder, entry, pathList, cb) ->
  return new Promise( (resolve, reject) ->
    pathList.add(entry.path)
    entry
      .pipe(fstream.Writer(path: path.join(outputFolder, entry.path)))
      .on("err", (err) ->
        reject(err)
        return
      )
      .on("close", ->
        resolve(entry.path)
        return
      )
    return
  )

###*
 * MODを適応します
 * @param {"add"|"delete"} type 適応するか解除するか
 * @param {string} mod "{repo: {type: repoType, name: repo}, name: name}"
 * @param {Function} callback 適応完了時に実行
 * @return {Promise}
 ###
applyMod = (type, mod, callback) ->
  pathType = config.get("blitzPathType")
  if pathType is "folder"
    outputFolder = path.normalize(config.get("blitzPath"))
  else
    outputFolder = TEMP_FOLDER
  try
    pathList = new Set()
    await fs.ensureDir(outputFolder)
    switch type
      when "add" then folder = "install"
      when "delete" then folder = "remove"
      else throw new Error("Unknown type")

    log = (phase) ->
      return callback(phase, type, mod)

    if mod.repo.type is "remote"
      stream = _getFromRemote(folder, mod, log)
    else if mod.repo.type is "local"
      stream = _getFromLocal(folder, mod)
      unless stream? then throw new Error("No Folder and Zip in Path")
    else
      throw new Error("Unknown RepoType")

    await new Promise( (resolve, reject) ->
      hasFile = false
      stream
        .on("data", (entry) ->
          hasFile = true
          try
            data = await _applyFromData(outputFolder, entry, pathList)
            pathList.delete(data)
            if pathList.size is 0
              resolve()
          catch e
            reject(e)
          return
        )
        .on("entry", (entry) ->
          return if entry.type is "Directory"
          hasFile = true
          try
            data = await _applyFromEntry(outputFolder, entry, pathList)
            pathList.delete(data)
            if pathList.size is 0
              resolve()
          catch err
            reject(err)
          return
        )
        .on("error", (err) ->
          reject(err)
          return
        )
        .on("end", ->
          resolve() unless hasFile
          return
        )
      return
    )

    if pathType is "file"
      callback("tempdone", type, mod)
      callback("zipcompress", type, mod)
      blitzPath = path.normalize(config.get("blitzPath"))
      switch config.get("platform")
        when "a" then prefix = "assets"
        when "i" then prefix = "Payload/wotblitz.app"
        else prefix = ""
      data = await fs.readFile(blitzPath)
      zip = await jszip.loadAsync(data)
      await new Promise( (resolve, reject) ->
        readdirp(root: outputFolder)
          .on("data", ({path: pa, fullPath}) ->
            zip.file(path.join(prefix, pa), fs.readFileSync(fullPath))
            return
          )
          .on("end", ->
            zip
              .generateNodeStream(streamFiles: true)
              .pipe(fs.createWriteStream(blitzPath))
              .on("finish", ->
                callback("zipcompressed", type, mod)
                resolve()
                return
              )
            return
          )
        return
      )

    switch type
      when "add" then config.add("appliedMods", {repo: mod.repo.name, name: mod.name})
      when "delete" then config.remove("appliedMods", {repo: mod.repo.name, name: mod.name})
    callback("done", type, mod)
    fs.remove(TEMP_FOLDER)
  catch err
    fs.remove(TEMP_FOLDER)
    callback("fail", type, mod, err)
  return

###*
 * 複数のMODを適応します
 * @param {Array[Object]} addMods "{repo: {type: repoType, name: repo}, name: name}"
 *     適応するMODの配列
 * @param {Array[Object]} deleteMods "{repo: {type: repoType, name: repo}, name: name}"
 *     解除するMODの配列
 * @param {Function} callback 適応完了時に実行
 * @return {Promise}
 ###
applyMods = (addMods, deleteMods, callback) ->
  await Promise.all(applyMod("delete", dmod, callback) for dmod in deleteMods)
  return Promise.all(applyMod("add", amod, callback) for amod in addMods)

module.exports = {
  applyMod
  applyMods
}
