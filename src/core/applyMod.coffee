###*
 * @fileoverview MODを適応/解除するメソッド群
 ###

path = require "path"
fs = require "fs-extra"
fetch = require "fetch"
unzip = require "unzipper"
config = require "./config"

###*
 * リモートからのMODを適応します
 ###
_applyFromRemote = (folder, mod, outputFolder) ->
  return new Promise( (resolve, reject) ->
    extractor = unzip.Extract(path: outputFolder)
    extractor.on("error", (err) ->
      reject(err)
      return
    )
    extractor.on("close", ->
      resolve()
      return
    )
    new fetch.FetchStream("#{mod.repo.name}/#{folder}/#{mod.name}.zip")
      .pipe(extractor)
    return
  )

###*
 * ローカルからのMODを適応します
 ###
_applyFromLocal = (folder, mod, outputFolder) ->
  return new Promise( (resolve, reject) ->
    fs.stat(path.join(mod.repo.name, folder, mod.name), (err, stats) ->
      if !err? and stats.isDirectory()
        _applyFromLocalFolder(folder, mod, outputFolder).then( ->
          resolve()
          return
        ).catch( (err) ->
          reject(err)
          return
        )
        return
      else
        fs.stat(path.join(mod.repo.name, folder, mod.name + ".zip"), (err, stats) ->
          if !err? and stats.isFile()
            _applyFromLocalZip(folder, mod, outputFolder).then( ->
              resolve()
              return
            ).catch( (err) ->
              reject(err)
              return
            )
          else
            reject()
          return
        )
      return
    )
    return
  )

###*
 * ローカルのMOD(フォルダになっているもの)を適応します
 ###
_applyFromLocalFolder = (folder, mod, outputFolder) ->
  return new Promise( (resolve, reject) ->
    fs.copy(path.join(mod.repo.name, folder, mod.name), outputFolder, clobber: true, (err) ->
      if err? then reject(err) else resolve()
      return
    )
    return
  )

###*
 * ローカルのMOD(zipになっているもの)を適応します
 ###
_applyFromLocalZip = (folder, mod, outputFolder) ->
  return new Promise( (resolve, reject) ->
    fs.createReadStream(path.join(mod.repo.name, folder, mod.name + ".zip"))
      .pipe(unzip.Extract(path: outputFolder))
      .on("error", (err) ->
        reject(err)
        return
      )
      .on("close", ->
        resolve()
        return
      )
  )

###*
 * MODを適応します
 * @param {"add"|"delete"} type 適応するか解除するか
 * @param {string} mod "{repo: {type: repoType, name: repo}, name: name}"
 * @param {Function} callback 適応完了時に実行
 * @return {Promise}
 ###
applyMod = (type, mod, callback) ->
  outputFolder = path.normalize(config.get("blitzPath"))
  return new Promise( (resolve, reject) ->
    fs.ensureDirSync(outputFolder)
    switch type
      when "add" then folder = "install"
      when "delete" then folder = "remove"
      else reject("Unknown type")
    if mod.repo.type is "remote"
      _applyFromRemote(folder, mod, outputFolder).then( ->
        resolve()
        return
      ).catch( (err) ->
        reject(err)
        return
      )
      return
    else if mod.repo.type is "local"
      _applyFromLocal(folder, mod, outputFolder).then( ->
        resolve()
        return
      ).catch( (err) ->
        reject(err)
        return
      )
      return
    else
      reject("Unknown RepoType")
  ).then( ->
    switch type
      when "add" then config.add("appliedMods", {repo: mod.repo.name, name: mod.name})
      when "delete" then config.remove("appliedMods", {repo: mod.repo.name, name: mod.name})
    callback(true, type, mod)
    return
  ).catch( (err) ->
    callback(false, type, mod, err)
    return
  )

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
  deleteDeferArray = []
  for dmod in deleteMods
    deleteDeferArray.push(applyMod("delete", dmod, callback))
  addDeferArray = []
  for amod in addMods
    addDeferArray.push(applyMod("add", amod, callback))
  dLen = deleteDeferArray.length
  aLen = addDeferArray.length
  if dLen > 0 and aLen > 0
    return Promise.all(deleteDeferArray).then( ->
      return Promise.all(addDeferArray)
    )
  else if dLen > 0
    return Promise.all(deleteDeferArray)
  else if aLen > 0
    return Promise.all(addDeferArray)
  else
    return Promise.resolve()

module.exports =
  applyMod: applyMod
  applyMods: applyMods
