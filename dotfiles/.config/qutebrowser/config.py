# qutebrowser configuration
config.load_autoconfig()


# Search engines
c.url.searchengines = {
    "DEFAULT": "https://www.google.com/search?q={}",
    "sg": "https://www.google.com/search?q={}",
    "sb": "https://search.bilibili.com/all?keyword={}",
    "sh": "https://github.com/search?q={}",
    "sl": "https://linux.do/search?q={}",
}

# Start page
c.url.start_pages = ["https://gemini.google.com"]

# Fonts
c.fonts.default_size = "12pt"
c.fonts.default_family = "CaskaydiaMono Nerd Font Mono, Sarasa Mono SC"

# Prefer Chinese UI content
c.content.headers.accept_language = "zh-CN,zh;q=0.9,en;q=0.8"

# Persist sessions automatically
c.auto_save.session = True

# Limit the cache to avoid excessive memory usage
c.qt.chromium.low_end_device_mode = "auto"
c.content.cache.size = 52428800  # 50MB

# Translation shortcut
config.bind("tt", "spawn --userscript translate")

# Local service shortcuts
config.bind(",pve", "open -t https://10.0.0.254:8006")
config.bind(",rt", "open -t http://10.0.0.1")
config.bind(",api", "open -t http://10.0.0.253:3000")
config.bind(",ql", "open -t http://10.0.0.253:5700")
config.bind(",pr", "open -t http://10.0.0.1:9090/ui/zashboard")
config.bind(",cpa", "open -t http://10.0.0.253:8317/management.html")
config.bind(",opl", "open -t http://10.0.0.253:5244")
config.bind(",ctn", "open -t http://10.0.0.253:9000")
