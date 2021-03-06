path = require 'path'
{$, $$$, EditorView, File, ScrollView} = require 'atom'
_ = require 'underscore-plus'
{extensionForFenceName} = require './extension-helper'

module.exports =
class MarkdownPreviewView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: ({filePath}) ->
    new MarkdownPreviewView(filePath)

  @content: ->
    @div class: 'markdown-preview native-key-bindings', tabindex: -1

  constructor: (filePath) ->
    super
    @file = new File(filePath)
    @handleEvents()

  serialize: ->
    deserializer: 'MarkdownPreviewView'
    filePath: @getPath()

  destroy: ->
    @unsubscribe()

  handleEvents: ->
    @subscribe atom.syntax, 'grammar-added grammar-updated', _.debounce((=> @renderMarkdown()), 250)
    @subscribe this, 'core:move-up', => @scrollUp()
    @subscribe this, 'core:move-down', => @scrollDown()
    @subscribe @file, 'contents-changed', =>
      @renderMarkdown()
      paneView = @getPaneView()
      paneView.showItem(this) if paneView? and paneView isnt atom.workspaceView.getActivePaneView()

  renderMarkdown: ->
    @showLoading()
    @file.read().then (contents) =>
      roaster = require 'roaster'
      roaster contents, (error, html) =>
        if error
          @showError(error)
        else
          @html(@tokenizeCodeBlocks(html))

  getTitle: ->
    "#{path.basename(@getPath())} Preview"

  getUri: ->
    "markdown-preview://#{@getPath()}"

  getPath: ->
    @file.getPath()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing Markdown Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @html $$$ ->
      @div class: 'markdown-spinner', 'Loading Markdown...'

  tokenizeCodeBlocks: (html) =>
    html = $(html)
    preList = $(html.filter("pre"))

    for preElement in preList.toArray()
      $(preElement).addClass("editor-colors")
      codeBlock = $(preElement.firstChild)

      # go to next block unless this one has a class
      continue unless className = codeBlock.attr('class')

      fenceName = className.replace(/^lang-/, '')
      # go to next block unless the class name matches `lang`
      continue unless extension = extensionForFenceName(fenceName)
      text = codeBlock.text()

      grammar = atom.syntax.selectGrammar("foo.#{extension}", text)

      codeBlock.empty()
      for tokens in grammar.tokenizeLines(text)
        codeBlock.append(EditorView.buildLineHtml({ tokens, text }))

    html

  getPaneView: ->
    @parents('.pane').view()
