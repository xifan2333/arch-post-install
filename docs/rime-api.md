# 编程接口

本节详细介绍编程接口。根据我们此前讲过的约定，以下假定所编写的 Lua 组件位于 `lua/my_ime` 子文件夹下，即为 `lua/my_ime/xxx.lua`，且导入时不指定相关的命名空间。您也可以使用上面介绍过的命名空间、子文件夹以及 Lua 表等方式来更灵活地组织您的脚本。

## Lua 处理器 `lua_processor`
`lua_processor` 提供了处理器的开发接口。它在配置文件的 `engine/processors` 中配置：

```yaml
engine:
  processors:
    - lua_processor@*my_ime.my_processor
```

`my_processor` 所指对象有多种形式：

```lua
--- 简化形式 1
local function my_processor(key_event)
  ...
end

--- 简化形式 2
local function my_processor(key_event, env)
  ...
end

--- 完整形式
local my_processor = {
   init = function (env) ... end,
   func = function (key_event, env) ... end,
   fini = function (env) ... end
}
```

简化形式是一个 Lua 函数，此函数执行处理器的逻辑，参数为：

- `key_event`：[`KeyEvent` 对象](./objects#keyevent)，为待处理的按键（包括带修饰符的组合键）。
- `env`：`Env` 对象，包括 `engine` 和 `name_space` 两个成员，分别是 [`Engine` 对象](./objects#engine)和前述 `name_space` 配置字符串。

返回值为 0、1 或 2：

- 0 表示 `kRejected`，声称本组件和其他组件都不响应该输入事件，结束处理流程，交还由操作系统按默认方式响应（例如 ASCII 字符上屏、方向翻页等功能键作用于客户程序或系统全局等）。
   - 注意：如果组件已响应该输入事件但返回 `kRejected`，则按键会再被操作系统处理一次，有可能产生「处理了两次」的效果。
- 1 表示 `kAccepted`，声称本组件已响应该输入事件，结束处理流程，之后的组件以及操作系统都不再需要响应该输入事件。
   - 注意：如果组件未响应该输入事件但返回 `kAccepted`，相当于禁用这个按键
- 2 表示 `kNoop`，声称本函数不响应该输入事件，交给接下来的处理器决定。
   - 注意：如果组件已响应该输入事件但返回 `kNoop`，则按键会再被接下来的组件处理一次或多次，有可能产生「处理了多次」的效果。
   - 如果所有处理器都返回 `kNoop`，则交还由操作系统按默认方式响应。

而完整形式是一个 Lua 表，其中 `func` 与简化形式意义相同。`init` 与 `fini` 分别在组件构造与析构时调用。

## Lua 分段器 `lua_segmentor`
`lua_segmentor` 提供了分段器的开发接口。它在配置文件的 `engine/segmentor` 中配置：

```yaml
engine:
  segmentors:
    - lua_segmentor@*my_ime.my_segmentor
```

`my_segmentor` 所指对象有多种形式：

```lua
--- 简化形式 1
local function my_segmentor(segmentation)
  ...
end

--- 简化形式 2
local function my_segmentor(segmentation, env)
  ...
end

--- 完整形式
local my_segmentor = {
  init = function (env) ... end,
  func = function (segmentation, env) ... end,
  fini = function (env) ... end
}
```

简化形式是一个 Lua 函数，此函数执行分段器的逻辑，参数为：

- `segmentation`：[`Segmentation` 对象](./objects#segmentation)。
- `env`：`Env` 对象，含义同前。

而返回值为布尔类型：

- `true`: 交由下一个分段器处理
- `false`: 终止分段器处理流程

而完整形式是一个 Lua 表，其中 `func` 与简化形式意义相同。`init` 与 `fini` 分别在组件构造与析构时调用。

## Lua 翻译器 `lua_translator`
`lua_translator` 提供了翻译器的开发接口。它在配置文件的 `engine/translator` 中配置：

```yaml
engine:
  translators:
    - lua_translator@*my_ime.my_translator
```

`my_translator` 所指对象有多种形式：

```lua
--- 简化形式 1
local function my_translator(input, segment)
  ...
end

--- 简化形式 2
local function my_translator(input, segment, env)
  ...
end

--- 完整形式
local my_translator = {
  init = function (env) ... end,
  func = function (input, segment, env) ... end,
  fini = function (env) ... end
}
```

简化形式是一个 Lua 函数，此函数执行翻译器的逻辑，参数为：

- `input`：`string` 类型的字符串，为待翻译串。
- `segment`：[`Segment` 对象](./objects#segment)。
- `env`：`Env` 对象，含义同前。

函数无返回值，而是通过 `yield` 发送 [`Candidate` 对象](./objects#candidate-候选词)或其他的候选对象。

而完整形式是一个 Lua 表，其中 `func` 与简化形式意义相同。`init` 与 `fini` 分别在 `lua_translator` 构造与析构时调用。

## Lua 过滤器 `lua_filter`
`lua_filter` 提供了过滤器的开发接口。它在配置文件的 `engine/filters` 中配置：

```yaml
engine:
  filters:
    - lua_filter@*my_ime.my_filter
```

`my_filter` 所指对象有多种形式：

```lua
--- 简化形式 1
local function my_filter(translation)
  ...
end

--- 简化形式 2
local function my_filter(translation, env)
  ...
end

--- 完整形式
local my_filter = {
   init = function (env) ... end,
   func = function (translation, env) ... end,
   fini = function (env) ... end,
   tags_match = function (segment, env) ... end  --- 可选
}
```

简化形式是一个 Lua function，此函数执行过滤器的逻辑，参数为

- `translation`：[`Translation` 对象](./objects)，为待过滤的 `Candidate` 流。
- `env`：`Env` 对象，含义同前。

函数无返回值，而是通过 `yield` 发送 `Candidate` 对象或其他的候选对象。

而完整形式是一个 Lua 表，其中 `func` 与简化形式意义相同。`init` 与 `fini` 分别在 `lua_filter` 构造与析构时调用。另外，`tags_match` 出现时可以指定该过滤器只在某种特定情况下工作，通常是使用 `segment` 所包含的 `tag` 来判断。