# qutebrowser配置
config.load_autoconfig()

# Google 账户使用 Chrome user agent 避免登录被阻止
chrome_ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
config.set('content.headers.user_agent', chrome_ua, 'https://accounts.google.com/*')
config.set('content.headers.user_agent', chrome_ua, 'https://*.google.com/*')

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

# 字体设置
c.fonts.default_size = '12pt'
c.fonts.default_family = 'CaskaydiaMono Nerd Font Mono, Sarasa Mono SC'

# 设置界面语言为中文
c.content.headers.accept_language = 'zh-CN,zh;q=0.9,en;q=0.8'

# 自动保存会话
c.auto_save.session = True

# 快速访问常用网站
config.bind(',bl', 'open -t https://www.bilibili.com')
config.bind(',gm', 'open -t https://gemini.google.com')
config.bind(',gpt', 'open -t https://chatgpt.com')
config.bind(',ld', 'open -t https://linux.do')
config.bind(',cf', 'open -t https://dash.cloudflare.com')
config.bind(',db', 'open -t https://www.douban.com')
config.bind(',do', 'open -t https://www.doubao.com')
config.bind(',ff', 'open -t https://fanfou.pro')
