# Reopen the previous session on program start
c.auto_save.session = True
# Open middle/ctrl+click tabs in the background
c.tabs.background = True
# When the last tab is closed, open the start page
c.tabs.last_close = 'startpage'

# Key bindings
config.bind('t', 'set-cmd-text -s :open -t')

# Search engines
c.url.searchengines = {
    'DEFAULT': 'https://www.google.com/search?hl=en&q={}',
    'google': 'https://www.google.com/search?hl=en&q={}',
}
