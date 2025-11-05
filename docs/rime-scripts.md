# 脚本开发指南

librime-lua 是 Rime 输入法引擎的一个插件，它为用户提供了使用 Lua 脚本语言扩展输入法的能力。通过 Lua，您可以实现单纯使用配置文件难以做到的灵活多样的功能，比如输入任意动态短语（日期时间、大写数字、计算器……）、自由重排/过滤候选词、甚至云输入等。

要理解本项目的工作原理，需先了解 Rime 功能组件的基本概念与工作流程，见 [Rime 输入方案](https://rimeinn.github.io/rime/schema-design.html#详解输入方案)。简而言之，librime-lua 提供了处理器 `processor`、分段器 `segmentor`、翻译器 `translator` 和过滤器 `filter` 这四类组件的开发接口。本文通过一个例子来说明使用 librime-lua 开发组件的完整流程，然后在下一篇文章中详细介绍各类组件的编程接口。

## 例子：输入今天的日期
我们通过「输入今天的日期」这个例子，来说明开发定制的流程。一共分三步：编写代码、配置方案、重新部署。

### 编写代码
我们希望在输入 "date" 之后，在输入法候选框中得到今天日期。为此，我们需要一个能产生今天日期的翻译器。我们在 Rime 的用户目录下新建一个 `rime.lua` 文件，这是 Lua 脚本的总入口。在文件中添加以下内容：

```lua
-- rime.lua
function date_translator(input, segment)
   if (input == "date") then
      --- Candidate(type, start, end, text, comment)
      yield(Candidate("date", segment.start, segment._end, os.date("%Y年%m月%d日"), " 日期"))
   end
end
```

上面实现了一个叫做 `date_translator` 的函数。它的输入是 `input` 和 `segment`，分别传入了翻译器需要翻译的内容和它在输入串中的位置。这个函数会判断输入的是否是 `"date"`。如是则生成一个内容为今天日期的候选项。候选项的构造函数是 `Candidate`。这个函数如注释所说有五个参数：类型、开始位置、结束位置、候选内容和候选注释。

- 类型可以是任意字符串，这里用了 `"date"`；
- 开始、结束位置一般用 `segment.start` 和 `segment._end` 就可以，它表示了我们要将整个待翻译的输入串替换为候选内容；
- 候选内容是使用 Lua 的库函数生成的日期；
- 候选注释是「日期」，这会在输入候选框中展示在候选内容旁边。

候选项生成以后是通过 `yield` 发出的。`yield` 在这里可以简单理解为「发送一个候选项到候选框中」。一个函数可以 `yield` 任意次，这里我们只有一个候选项所以只有一个 `yield`。

### 配置方案
我们已经编写了输入日期的翻译器。为了让它生效，需要修改输入方案的配置文件。以朙月拼音为例，找到 `luna_pinyin.schema.yaml`，在 `engine/translators` 中加入一项 `lua_translator@date_translator`，如下：

```yaml
# luna_pinyin.schema.yaml
engine:
  ...
  translators:
    - lua_translator@date_translator
    ...
```

这样就完成了配置。它表示从 lua 执行环境中找到名为 `date_translator` 的对象，将它作为一种翻译器添加到引擎之中。其他类型的组件配置类推，分别叫做 `lua_processor`、`lua_segmentor`、`lua_filter`。

### 重新部署
以上完成了所有开发和配置。点击「重新部署」，输入 "date"，就可以看到候选框中出现了今天的日期。

在[本项目的示例目录](https://github.com/hchunhui/librime-lua/tree/master/sample)下，还有更多的例子。配合其中的注释并稍加修改，就可以满足大部分的日常需求。

## 模块化
到目前为止，我们的代码完全集中在 `rime.lua` 中。本节说明 librime-lua 对模块化的支持。模块化是指把脚本分门别类，放到独立的文件中，避免各自的修改互相干扰，也方便把自己的作品分享给他人使用。仍然以 `date_translator` 为例。

### 分离脚本内容
首先需要把原来写在 `rime.lua` 的脚本搬运到独立的文件中。删掉 `rime.lua` 原有的内容后，在 Rime 的用户目录下新建一个 `lua` 目录，在该目录下再建立一个 `date_translator.lua` 文件，录入以下内容：

```lua
-- lua/date_translator.lua
local function translator(input, seg)
   if (input == "date") then
      --- Candidate(type, start, end, text, comment)
      yield(Candidate("date", seg.start, seg._end, os.date("%Y年%m月%d日"), " 日期"))
   end
end

return translator
```

可以看到主要内容与之前一致，但有两点不同：
- 使用 `local`。lua 脚本的变量作用域默认是全局的。如果不同模块的变量或函数正好用了相同的名字，就会导致互相干扰，出现难以排查的问题。因此，尽量使用 `local` 把变量作用域限制在局部。
- 新增 `return`。librime-lua 是借助 lua 的 require 机制实现模块加载。引用模块时，整个文件被当作一个函数执行，返回模块内容。在这里返回的是一个翻译器组件。

### 配置方案直接引用模块
我们已经建立了一个名叫 `date_translator` 的模块。我们可以在输入方案配置文件中写入以下内容来直接引用这个模块所返回的组件，而不是从全局的 `rime.lua` 中获取组件：

```yaml
# luna_pinyin.schema.yaml
engine:
  ...
  translators:
    - lua_translator@*date_translator
  ...
```

与之前的区别是第一个 `@` 之后多了一个 `*`。这个星号表示后面的名字是模块名而不是全局变量名。当遇到星号时，librime-lua 会使用 require 机制加载模块，然后将其返回值作为 Rime 组件加载到输入法框架中。

### 更多引用的方式

首先，您可以对同一个 Lua 组件加载多个实例，此时需要用 `@namespace` 的语法标注出命名空间以区分不同的实例：

```yaml
engine:
  translators: 
    - lua_translator@*date_translator # name_space "date_translator"
    - lua_translator@*date_translator@date # namespace "date"
```

其次，您还可以引用位于 `lua/` 文件夹下的子文件夹中的模块，此时路径的分隔符可以用 `.`，也可以用 `/`，例如：

```yaml
engine:
  translators:
    - lua_translator@*date.translator # lua/date/translator.lua
    - lua_translator@*date/translator # lua/date/translator.lua
    - lua_translator@*date/subdir/translator # lua/date/subdir/translator.lua
```

最后，若一个文件通过 Lua 表的方式导出了多个组件，使用 `*` 还可以在表中进一步搜索，例如

```yaml
engine:
  translators:
    - lua_translator@*module_name*subtable1*subtable2*tran@name_space
  processors:
    - lua_translator@*module_name*subtable1*subtable2*proc@name_space
```

对应了以下的用表组织起来的多个组件：

```lua
-- lua/module_name.lua
return {
  subtable1 = {
     subtable2 = {
        tran = function (input, segment, env) ... end,
        proc = function (key, env) ... end,
        filter = function (translation, env) ... end,
     },
  },
  subtable2 = { ... },                            
  subtable3 = { ... },
}
```

## 旧版 librime-lua 的使用方式
如果使用的是较旧的 librime-lua，则配置文件不能直接载入在子目录中的 Lua 模块。在将模块分离出去之后，仍然需要在 `rime.lua` 内输入以下内容：

```lua
date_translator = require("date_translator")
```

前一个 `date_translator` 是全局变量名，后一个是模块名。librime-lua 将 Rime 的用户目录和 Rime 共享目录下的 `lua` 目录加入了模块搜索路径，因此本句的意义是搜索 `date_translator` 模块，并将返回的组件绑定到同名的全局变量上。这样就可以在输入方案配置文件中使用了，方法与之前一致。

## 配方补丁
以上我们实现了 lua 脚本的模块化。但为引用组件，仍需修改 `schema.yaml` 配置文件。关于如何模块化地修改配置文件，请参考 [Rime 配置文件](https://rimeinn.github.io/rime/configuration.html)中关于补丁的讲解。

## 下一步
请查看[编程接口](./api)来了解更多编写组件的方式。