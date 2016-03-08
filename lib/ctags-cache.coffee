
TagGenerator = require './tag-generator'
ctags = require 'ctags'
fs = require "fs"
path = require "path"
async = require 'async'

getTagsFile = (directoryPath) ->
  tagsFile = path.join(directoryPath, ".tags")
  return tagsFile if fs.existsSync(tagsFile)

matchOpt = {matchBase: true}
module.exports =
  activate: () ->
    @cachedTags = []
    @extraTags = []

  deactivate: ->
    @cachedTags = null

  initTags: (paths, auto)->
    return if paths.length == 0
    @cachedTags = []
    for p in paths
      tagsFile = getTagsFile(p)
      if tagsFile
        @readTags(tagsFile, @cachedTags)
      else
        @generateTags(p) if auto

  initExtraTags: (paths) ->
    @extraTags = []
    for p in paths
      p = p.trim()
      continue unless p
      @readTags(p, @extraTags)

  readTags: (p, container, callback) ->
      console.log "Not caching tags for stability."
      container.push(p) if container.indexOf(p) < 0
      callback?()

  #options = { partialMatch: true, maxItems }
  findTags: (prefix, options, callback) ->
    items = []
    items.push({'path': path, 'prefix': prefix, 'options': options}) for path in @cachedTags
    items.push({'path': path, 'prefix': prefix, 'options': options}) for path in @extraTags

    async.concat items, @findOf, (error, tags) ->
      #TODO: prompt in editor
      console.warn("[atom-ctags:findTags] tags empty, did you RebuildTags or set extraTagFiles?") if tags.length == 0
      callback error, tags

  findOf: (config, callback)->
    ctags.findTags config.path, config.prefix, config.options, callback

  generateTags:(p, isAppend, callback) ->
    startTime = Date.now()
    console.log "[atom-ctags:rebuild] start @#{p}@ tags..."

    cmdArgs = atom.config.get("atom-ctags.cmdArgs")
    cmdArgs = cmdArgs.split(" ") if cmdArgs

    TagGenerator p, isAppend, @cmdArgs || cmdArgs, (tagpath) =>
      console.log "[atom-ctags:rebuild] command done @#{p}@ tags. cost: #{Date.now() - startTime}ms"

      startTime = Date.now()
      @readTags(tagpath, @cachedTags, callback)

  getOrCreateTags: (filePath, callback) ->
    tags = @cachedTags[filePath]
    return callback?(tags) if tags

    @generateTags filePath, true, =>
      tags = @cachedTags[filePath]
      callback?(tags)
