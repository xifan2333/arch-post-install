# qutebrowser配置
config.load_autoconfig()

# 设置搜索引擎
c.url.searchengines = {
    'DEFAULT': 'https://www.google.com/search?q={}',
    'b': 'https://www.baidu.com/s?wd={}',
    'gh': 'https://github.com/search?q={}',
}

# 设置主页为Gemini
c.url.start_pages = ['https://gemini.google.com']

# 启用广告拦截
c.content.blocking.enabled = True

# 字体大小
c.fonts.default_size = '12pt'
