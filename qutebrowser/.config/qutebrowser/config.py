# Reopen the previous session on program start
c.auto_save.session = True
# Open middle/ctrl+click tabs in the background
c.tabs.background = True
# When the last tab is closed, open the start page
c.tabs.last_close = 'startpage'

# Key bindings
config.bind('t', 'set-cmd-text -s :open -t')
config.bind('O', 'set-cmd-text :open {url:pretty}')

# Default homepage
c.url.default_page = "https://web.tabliss.io/"
c.url.start_page = "https://web.tabliss.io/"

# Search engines
c.url.searchengines = {
    'DEFAULT': 'https://www.google.com/search?hl=en&q={}',
    'google': 'https://www.google.com/search?hl=en&q={}',
}

config.load_autoconfig(False)
