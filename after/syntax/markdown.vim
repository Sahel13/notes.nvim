" Highlight wiki-links [[...]] without Tree-sitter, matching normal link text.
syntax match markdownWikiLink /\[\[[^]\r\n]\+\]\]/
hi def link markdownWikiLink markdownLinkText
