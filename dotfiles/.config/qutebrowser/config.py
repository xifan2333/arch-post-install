# qutebrowser配置
config.load_autoconfig()

# 设置搜索引擎
c.url.searchengines = {
    'DEFAULT': 'https://www.google.com/search?q={}',
    'sg': 'https://www.google.com/search?q={}',
    'sb': 'https://search.bilibili.com/all?keyword={}',
    'sh': 'https://github.com/search?q={}',
    'sl': 'https://linux.do/search?q={}',
}

# 设置主页为Gemini
c.url.start_pages = ['https://gemini.google.com']

# 启用广告拦截
c.content.blocking.enabled = True
c.content.blocking.method = 'both'

# 字体大小
c.fonts.default_size = '12pt'

# 暗色模式
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.policy.images = 'never'

# 自动保存会话
c.auto_save.session = True

# 快速访问常用网站
config.bind(',bl', 'open -t https://www.bilibili.com')
config.bind(',gm', 'open -t https://gemini.google.com')
config.bind(',gpt', 'open -t https://chatgpt.com')
config.bind(',ld', 'open -t https://linux.do')
config.bind(',cf', 'open -t https://dash.cloudflare.com')
config.bind(',v2', 'open -t http://127.0.0.1:2017')
config.bind(',db', 'open -t https://www.douban.com')
config.bind(',do', 'open -t https://www.doubao.com')
config.bind(',ff', 'open -t https://fanfou.pro')
