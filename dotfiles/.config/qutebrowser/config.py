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

# 翻译快捷键
config.bind('tt', 'spawn --userscript translate')

# 快速访问本地服务
config.bind(',pve', 'open -t http://10.0.0.254')
config.bind(',rt', 'open -t http://10.0.0.1')
config.bind(',api', 'open -t http://10.0.0.253:3000')
config.bind(',ql', 'open -t http://10.0.0.253:5700')
config.bind(',pr', 'open -t http://10.0.0.1:9090/ui/zashboard')
config.bind(',cpa', 'open -t http://10.0.0.253:8317/management.html')
config.bind(',opl', 'open -t http://10.0.0.253:5244')
config.bind(',ctn', 'open -t http://10.0.0.253:9000')
