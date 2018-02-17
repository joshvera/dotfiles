atom.commands.add('atom-text-editor', 'syntax:log-selected-node', (event) => {
  const editor = event.target.closest('atom-text-editor').getModel()
  const languageMode = editor.getBuffer().getLanguageMode()
  if (!languageMode.document) return
  for (const range of editor.getSelectedBufferRanges()) {
    console.log(languageMode.document.rootNode.namedDescendantForPosition(range.start, range.end).toString())
  }
})