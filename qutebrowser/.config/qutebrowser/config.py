# Reopen the previous session on program start
c.auto_save.session = True
# Open middle/ctrl+click tabs in the background
c.tabs.background = True
# When the last tab is closed, open the start page
c.tabs.last_close = 'startpage'

# Key bindings
config.bind('t', 'cmd-set-text -s :open -t')
config.bind('O', 'cmd-set-text :open {url:pretty}')

# Default homepage
c.url.default_page = "https://web.tabliss.io/"
c.url.start_pages = ["https://web.tabliss.io/"]

# Search engines
c.url.searchengines = {
    'DEFAULT': 'https://kagi.com/search?q={}',
    'kagi': 'https://kagi.com/search?q={}',
    'google': 'https://www.google.com/search?hl=en&q={}',
}

config.load_autoconfig(False)
