# 对象接口
librime-lua 封装了 librime C++ 对象到 lua 中供脚本访问。需注意随着项目的开发，以下文档可能是不完整或过时的，敬请各位参与贡献文档。

## Engine

可通过 `env.engine` 获得。

属性：

属性名 | 类型 | 解释
--- | --- | --- 
schema | 
context | Context | 
active_engine | 

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
process_key
compose
commit_text(text) | text: string | | 上屏 text 字符串
apply_schema

## Context

输入编码上下文。

可通过 `env.engine.context` 获得。  ( *W : 觸發 Compose() )

属性：

属性名 | 类型 | 解释
--- | --- | --- 
composition | Composition | 
input | string | *W 正在输入的编码字符串
caret_pos | number | *W 脱字符`‸`位置（以raw input中的ASCII字符数量标记）
commit_notifier | Notifier | 
select_notifier | Notifier | 
update_notifier | Notifier | 
delete_notifier | Notifier | 
option_update_notifier | OptionUpdateNotifier | 选项改变通知，使用 connect 方法接收通知
property_update_notifier | PropertyUpdateNotifier | 
unhandled_key_notifier | KeyEventNotifier | 

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
commit | | | 上屏选中的候选词
get_commit_text | | string |
get_script_text | | string | 按音节分割
get_preedit | | Preedit | 
is_composing | | boolean | 是否正在输入（输入字符串非空或候选词菜单非空）
has_menu | | boolean | 是否有候选词（选项菜单）
get_selected_candidate | | Candidate | 返回选中的候选词
push_input(text) | text: string | | *W 在caret_pos位置插入指定的text编码字符串，caret_pos跟隨右移
pop_input(num) | num: number | boolean | *W 在caret_pos位置往左删除num指定数量的编码字符串，caret_pos跟隨左移
delete_input
clear | | | *W 清空正在输入的编码字符串及候选词
select(index) | index: number | boolean | 选择第index个候选词（序号从0开始）
confirm_current_selection | | 确认选择当前高亮选择的候选词（默认为第0个）
delete_current_selection | | boolean | 删除当前高亮选择的候选词（自造词组从词典中删除；固有词则删除用户输入词频）（returning true doesn't mean anything is deleted for sure） <br> [https://github.com/rime/librime/.../src/context.cc#L125-L137](https://github.com/rime/librime/blob/fbe492eefccfcadf04cf72512d8548f3ff778bf4/src/context.cc#L125-L137)
confirm_previous_selection
reopen_previous_selection *W
clear_previous_segment
reopen_previous_segment *W
clear_non_confirmed_composition
refresh_non_confirmed_composition *W
set_option
get_option
set_property(key, value) | key: string <br> value: string | | 可以用于存储上下文信息（可配合 `property_update_notifier` 使用）
get_property(key) | key: string | string | 
clear_transient_options

## Preedit

属性：

属性名 | 类型 | 解释
--- | --- | ---
text
caret_pos
sel_start
sel_end

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---

## Composition

用户编写的“作品”。（通过此对象，可间接获得“菜单menu”、“候选词candidate”、“片段segment”相关信息）

可通过 `env.engine.context.composition` 获得。

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
empty | | boolean | 尚未开始编写（无输入字符串、无候选词）
back | | Segment | 获得队尾（input字符串最右侧）的 Segment 对象
pop_back | | | 去掉队尾的 Segment 对象
push_back(seg) | seg: Segment | | 在队尾添加一个 Segment对象
has_finished_composition
get_prompt | | string | 获得队尾的 Segment 的 prompt 字符串（prompt 为显示在 caret 右侧的提示，比如菜单、预览输入结果等）
toSegmentation


e.g.
```lua
local composition = env.engine.context.composition

if(not composition:empty()) then
  -- 获得队尾的 Segment 对象
  local segment = composition:back()

  -- 获得选中的候选词序号
  local selected_candidate_index = segment.selected_index

  -- 获取 Menu 对象
  local menu = segment.menu

  -- 获得（已加载）候选词数量
  local loaded_candidate_count = menu:candidate_count()
end
```

## Segmentation

在分词处理流程 Segmentor 中存储 Segment 并把其传递给 Translator 进行下一步翻译处理。

作为第一个参数传入以注册的 lua_segmentor。

或通过以下方法获得：

```lua
local composition = env.engine.context.composition
local segmentation = composition:toSegmentation()
```

> librime 定义 - https://github.com/rime/librime/blob/5c36fb74ccdff8c91ac47b1c221bd7e559ae9688/src/segmentation.cc#L28

属性：

属性名 | 类型 | 解释
--- | --- | ---
input | string | 活动中的原始（未preedit）输入编码

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
empty | | boolean | 是否包含 Segment 或 Menu
back | | Segment | 队尾（对应input最右侧的输入字符）的 Segment 
pop_back | | Segment | 移除队列最后的 Segment
reset_length| size_t | | 保留 n 個 Segment
add_segment(seg) | seg: Segment | | 添加 Segment <br>（librime v1.7.3：如果已包含 Segment 且起始位置相同，会取较长的Segment 并且合并 Segment.tags）
forward | | boolean | 新增 一個 kVoid 的 Segment(start_pos = 前一個 end_pos , end_pos = start_pos)
trim | | | 摘除队列最末位的0长度 Segment （0长度 Segment 用于语句流输入法中标记已确认`kConfirmed`但未上屏的 Segment 结束，用于开启一个新的 Segment）
has_finished_segmentation | | boolean | 
get_current_start_position | | number | 
get_current_end_position | | number | 
get_current_segment_length | | number | 
get_confirmed_position | | number | 属性 input 中已经确认（处理完）的长度 <br> （通过判断 status 为 `kSelected` 或 `kConfirmed` 的 Segment 的 _end 来判断 confirmed_position） <br> [https://github.com/rime/librime/.../src/segmentation.cc#L127](https://github.com/rime/librime/blob/cea389e6eb5e90f5cd5b9ca1c6aae7a035756405/src/segmentation.cc#L127)

e.g.
```txt
                         | 你hao‸a
env.engine.context.input | "nihaoa"
Segmentation.input       | "nihao"
get_confirmed_position   | 2
```

## Segment

分词片段。触发 translator 时作为第二个参数传递给注册好的 lua_translator。

或者以下方法获得: （在 filter 以外的场景使用）

```lua
local composition = env.engine.context.composition
if(not composition:empty()) then
  local segment = composition:back()
end
```

segment.tags 是一個Set 支援 "* + -" 運算，可用 "*" 檢查 has_tag

```lua
--  +: Set{'a', 'b'} + Set{'b', 'c'} return Set{'a', 'b', 'c'}
--  -: Set{'a', 'b'} - Set{'b', 'c'} return Set{'a'}
--  *: Set{'a', 'b'} * Set{'b', 'c'} return Set{'b'}
local tags = Set{'pinyin', 'reverse'}
local has_tag = not (seg.tags * tags):empty() -- 交集 (a , b) * (b, c)  ==>(b)
```

构造方法：`Segment(start_pos, end_pos)`
1. start_pos: 首码在输入字符串中的位置
2. end_pos: 尾码在输入字符串中的位置

属性：

属性名 | 类型 | 解释
--- | --- | ---
status | string | 1. `kVoid` - （默认） <br> 2. `kGuess` <br> 3. `kSelected` - 大于此状态才会被视为选中 <br> 4. `kConfirmed`
start
_start
_end
length
tags | Set | 标签
menu
selected_index
prompt | string | 输入编码以右的提示字符串 <br> ![image](https://user-images.githubusercontent.com/18041500/190980054-7e944f5f-a381-4c73-ad6a-254a00c09e44.png)

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
clear
close
reopen
has_tag
get_candidate_at(index) | index: number 序号0开始 | Candidate | 
get_selected_candidate | | Candidate | 

## Schema

方案。可以通过 `env.engine.schema` 获得。

构造方法：`Schema(schema_id)`
1. schema_id: string

属性：

属性名 | 类型 | 解释
--- | --- | --- 
schema_id | string | 方案编号
schema_name | string | 方案名称
config | Config | 方案配置
page_size | number | 每页最大候选词数
select_keys | | 选词按键（不一定是数字键，视输入方案而定）

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---

## Config

（方案的）配置。可以通过 `env.engine.schema.config` 获得

属性：

属性名 | 类型 | 解释
--- | --- | --- 

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
load_from_file
save_to_file
is_null(conf_path) | conf_path: string | 
is_value
is_list(conf_path) | conf_path: string | boolean | 1. 存在且为 ConfigList 返回 true <br> 2. 存在且不为 ConfigList 返回 false <br> 3. 不存在返回 true ⚠️
is_map
get_bool
get_int
get_double
get_string(conf_path) | conf_path: string |  string | 根据配置路径 conf_path 获取配置的字符串值
set_bool
set_int
set_double
set_string(path, str) | path: string <br> str: string | 
get_item
set_item(path, item) | path: string <br> item: ConfigItem | 
get_value
get_list(conf_path) | conf_path: string | ConfigList | 不存在或不为 ConfigList 时返回 nil
get_map(conf_path) | conf_path: string | ConfigMap | 不存在或不为 ConfigMap 时返回 nil
set_value(path, value) | path: string <br> value: ConfigValue | 
set_list
set_map
get_list_size

## ConfigMap

属性：

属性名 | 类型 | 解释
--- | --- | --- 
size | number | 
type | string | 如：“kMap”
element |  | 轉換成ConfigItem

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
set
get(key) | key: string | ConfigItem |
get_value(key) | key: string | ConfigValue | 
has_key | | boolean | 
clear
empty | | boolean | 
keys | | table | 

## ConfigList

属性：

属性名 | 类型 | 解释
--- | --- | --- 
size | number |
type | string | 如：“kList”
element |  |轉換成ConfigItem

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_at(index) | index: number <br> （下标从0开始）| ConfigItem |
get_value_at(index) | index: number <br> （下标从0开始）| ConfigValue | 
set_at
append
insert
clear
empty
resize

## ConfigValue

继承 ConfigItem

构造方法：`ConfigValue(str)`
1. str: 值（可通过 get_string 获得）

属性：

属性名 | 类型 | 解释
--- | --- | --- 
value | string | 
type | string | 如：“kScalar”
element| |轉換成ConfigItem

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_bool | | | `bool`是`int`子集，所以也可以用`get_int`来取得`bool`值
get_int
get_double
set_bool
set_int
set_double
get_string
set_string

## ConfigItem

属性：

属性名 | 类型 | 解释
--- | --- | --- 
type | string | 1. "kNull" <br> 2. "kScalar" <br> 3. "kList" <br> 4. "kMap"
empty

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_value | | | 当 type == "kScalar" 时使用
get_list | | | 当 type == "kList" 时使用
get_map | | | 当 type == "kMap" 时使用

## KeyEvent

按键事件对象。

> 当一般按键被按下、修饰键被按下或释放时均会产生按键事件（KeyEvent），触发 processor，此时 KeyEvent 会被作为第一个参数传递给已注册的 lua_processor。
* 一般按键按下时：生成该按键的keycode，此时保持按下状态的所有修饰键（Ctrl、Alt、Shift等）以bitwise OR形式储存于modifier中
* 修饰键被按下时：生成该修饰键的keycode，此时保持按下状态的所有修饰键（包括新近按下的这个修饰键）以bitwise OR形式储存于modifier中
* 修饰键被释放时：生成该修饰符的keycode，此时仍保持按下状态的所有修饰键外加一个通用的 `kRelease` 以bitwise OR形式储存于modifier中。

属性：

属性名 | 类型 | 解释
--- | --- | ---
keycode | number | 按键值，除ASCII字符外按键值与字符codepoint并不相等
modifier | | 当前处于按下状态的修饰键或提示有修饰键刚刚被抬起的`kRelease`

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
shift | | boolean | 触发事件时，shift是否被按下
ctrl | | boolean | 触发事件时，ctrl是否被按下
alt | | boolean | 触发事件时，alt/option是否被按下
caps <br> （CapsLk） | | boolean |
super | | boolean | 触发事件时，win/command是否被按下
release | | boolean | 是否因为修饰键被抬起`release`而触发事件
repr <br> （representation） | | string | 修饰键（含release）＋按键名（若没有按键名，则显示4位或6位十六进制X11按键码位 ≠ Unicode）
eq(key) <br> （equal） | key: KeyEvent | boolean | 两个 KeyEvent 是否“相等”
lt(key) <br> （less than） | key: KeyEvent | boolean | 对象小于参数时为 true

## KeySequence
> 形如`{按键1}{修饰键2+按键2}`的一串按键、组合键序列。一对花括号内的为一组组合键；序列有先后顺序

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
parse
repr
toKeyEvent

## Candidate 候选词

`Candidate` 缺省为 `SimpleCandidate`（选中后不会更新用户字典）

构造方法：`Candidate(type, start, end, text, comment)`
1. type: 来源和类别标记
1. start: 分词开始
1. end: 分词结束
1. text: 候选词内容
1. comment: 注释

属性：

属性名 | 类型 | 解释
--- | --- | ---
type | string | 候选词来源和类别标记，如：“user_phrase”、“phrase”、“punct”、“simplified” <br> 1. "user_phrase": 用户字典（随用户输入而更新） <br> 2. "phrase" <br> 3. "punct": 来源有两 "engine/segmentors/punct_segmentor" 或 "symbols:/patch/recognizer/patterns/punct" <br> 4. "simplified" <br> 5. "completion": 编码未完整。see [https://github.com/rime/librime/.../src/rime/gear/table_translator.cc#L77](https://github.com/rime/librime/blob/69d5c3291745faa184d7c020ce4b394d41744efd/src/rime/gear/table_translator.cc#L77) <br> 6...
start | number |
_start | number | 编码开始位置，如：“好” 在 “ni hao” 中的 _start=2
_end | number | 编码结束位置，如：“好” 在 “ni hao” 中的 _end=5
quality | number | 结果展示排名权重
text | string | 候选词内容
comment | string | 註解(name_space/comment_format) <br> ![image](https://user-images.githubusercontent.com/18041500/191151929-6d45e410-ccf8-4676-8146-c64bb3f4393e.png)
preedit | string | 得到当前候选词预处理后的输入编码（如形码映射字根、音码分音节加变音符，如："ni hao"）(name_space/preedit_format)

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_dynamic_type | | string | 1. "Phrase": Phrase <br> 2. "Simple": SimpleCandidate <br> 3. "Shadow": ShadowCandidate <br> 4. "Uniquified": UniquifiedCandidate <br> 5. "Other"
get_genuine | | Candidate | 
get_genuines | | table: `<number, Candidate>` | 
to_shadow_candidate
to_uniquified_candidate
append
to_phrase | | Phrase | 可能为 nil

## ShadowCandidate 衍生扩展词

<https://github.com/hchunhui/librime-lua/pull/162>

`ShadowCandidate`（典型地，simplifier 繁简转换产生的新候选词皆为`ShadowCandidate`）

构造方法：`ShadowCandidate(cand, type, text, comment, inherit_comment)`
1. cand
1. type
1. text
1. comment
1. inherit_comment: （可选）

## Phrase 词组

`Phrase`（选择后会更新相应的用户字典）

构造方法：`Phrase(memory, type, start, end, entry)`
1. memory: Memory
1. type: string
1. start: number
1. end: number
1. entry: DictEntry

属性：

属性名 | 类型 | 解释
--- | --- | ---
language
type
start
_start
_end
quality
text
comment
preedit
weight
code
entry

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
toCandidate

## UniquifiedCandidate 去重合并候选词

<https://github.com/hchunhui/librime-lua/pull/162>

`UniqifiedCandidate(cand, type, text, comment)` （典型地，uniqifier 合并重复候选词之后形成的唯一候选词即为`UniqifiedCandidate`）

## Set

构造方法：`Set(table)`
1. table: 列表

ex: `local set_tab = Set({'a','b','c','c'}) # set_tab = {a=true,b=true, c=true}`

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
empty
__index
__add
__sub
__mul
__set

## Menu

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
add_translation
prepare
get_candidate_at
candidate_count
empty

## Opencc

构造方法：`Opencc(filename)`
1. filename: string

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
convert

## ReverseDb / ReverseLookup

反查

构造方法：`ReverseDb(file_name)` 
1. file_name: 反查字典文件路径。 如: `build/terra_pinyin.reverse.bin`

e.g.
```lua
local pyrdb = ReverseDb("build/terra_pinyin.reverse.bin")
```

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
lookup | 

## ReverseLookup (ver #177)

构造方法：`ReverseLookup(dict_name)`
1. dict_name: 字典名。 如: `luna_pinyin`

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
lookup(key) | key: string | string | 如：`ReverseLookup("luna_pinyin"):lookup("百") == "bai bo"`
lookup_stems | 

## CommitEntry

继承 DictEntry

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get

## DictEntry

构造方法：`DictEntry()`

>librime 定义：https://github.com/rime/librime/blob/ae848c47adbe0411d4b7b9538e4a1aae45352c31/include/rime/impl/vocabulary.h#L33

属性：

属性名 | 类型 | 解释
--- | --- | ---
text | string | 词，如：“好”
comment | string | 剩下的编码，如：preedit "h", text "好", comment "~ao"
preedit | string | 如：“h”
weight | number | 如：“-13.998352335763”
commit_count | number | 如：“2”
custom_code | string | 词编码（根据特定规则拆分，以" "（空格）连接，如：拼音中以音节拆分），如：“hao”、“ni hao”
remaining_code_length | number | （预测的结果中）未输入的编码，如：preedit "h", text "好", comment "~ao"， remaining_code_length “2”
code | Code

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---

## Code

构造方法：`Code()`

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
push(inputCode) | rime::SyllableId <br> （librime中定义的类型） | 
print | | string | 

## Memory

提供来操作 dict（字典、固态字典、静态字典）和 user_dict（用户字典、动态字典）的接口


构造方法：`Memory(engine, schema, name_space)`
1. engine: Engine
2. schema: Schema
3. name_space: string （可选，默认为空）

* **Memory 字典中有userdb 須要在function fini(env) 中執行 env.mem:disconnect() 關閉 userdb 避免記憶泄露和同步(sync)報錯**

e.g.

```lua
env.mem = Memory(env.engine, env.engine.schema)  --  ns = "translator"
-- env.mem = Memory(env.engine, env.engine.schema, env.name_space)  
-- env.mem = Memory(env.engine, Schema("cangjie5")) --  ns = "translator-
-- env.mem = Memory(env.engine, Schema("cangjie5"), "translator") 
```

构造流程：https://github.com/rime/librime/blob/3451fd1eb0129c1c44a08c6620b7956922144850/src/gear/memory.cc#L51
1. 加载 schema 中指定的字典（dictionary）<br>
（包括："`{name_space}/dictionary`"、"`{name_space}/prism`"、"`{name_space}/packs`"）
2. 加在 schema 中指定的用户字典（user_dict）<br>
（前提：`{name_space}/enable_user_dict` 为 true）<br>
（包括："`{name_space}/user_dict`" 或 "`{name_space}/dictionary`"）<br>
（后缀："`*.userdb.txt`"）
3. 添加通知事件监听（commit_notifier、delete_notifier、unhandled_key_notifier）

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
dict_lookup(input, predictive, limit) | input: string <br> predictive: boolean <br> limit: number | boolean 是否有结果查询 | 
user_lookup(input, predictive) | input: string <br> predictive: boolean |
memorize(callback) | callback: function <br> （回调参数：CommitEntry） | 当用户字典候选词被选中时触发回调。
decode(code) | code: Code | table: `<number, string>` | 
iter_dict | |  | 配合 `for ... end` 获得 DictEntry
iter_user | |  | 配合 `for ... end` 获得 DictEntry
update_userdict(entry, commits, prefix) | entry: DictEntry <br> commits: number <br> prefix: string | boolean | 

使用案例：https://github.com/hchunhui/librime-lua/blob/67ef681a9fd03262c49cc7f850cc92fc791b1e85/sample/lua/expand_translator.lua#L32

e.g. 
```lua
-- 遍历

local input = "hello"
local mem = Memory(env.engine, env.engine.schema) 
mem:dict_lookup(input, true, 100)
-- 遍历字典
for entry in mem:iter_dict() do
 print(entry.text)
end

mem:user_lookup(input, true)
-- 遍历用户字典
for entry in mem:iter_user() do
 print(entry.text)
end
```

``````lua
-- 监听 & 更新

env.mem = Memory(env.engine, env.engine.schema) 
env.mem:memorize(function(commit) 
  for i,dictentry in ipairs(commit:get()) do
    log.info(dictentry.text .. " " .. dictentry.weight .. " " .. dictentry.comment .. "")
    -- memory:update_userdict(dictentry, 0, "") -- do nothing to userdict
    -- memory:update_userdict(dictentry, 1, "") -- update entry to userdict
    -- memory:update_userdict(dictentry, -1, "") -- delete entry to userdict
    --[[
      用户字典形式如：
      ```txt
      # Rime user dictionary
      #@/db_name	luna_pinyin.userdb
      #@/db_type	userdb
      #@/rime_version	1.5.3
      #@/tick	693
      #@/user_id	aaaaaaaa-bbbb-4c62-b0b0-ccccccccccc
      wang shang 	网上	c=1 d=0.442639 t=693
      wang shi zhi duo shao 	往事知多少	c=1 d=0.913931 t=693
      wang xia 	往下	c=1 d=0.794534 t=693
      wei 	未	c=1 d=0.955997 t=693
      ```
    --]]
  end
end
``````

## Projection

可以用于处理 candidate 的 comment 的转换

构造：`Projection()`

属性：

属性名 | 类型 | 解释
--- | --- | ---
Projection([ConfigList| string of table])
方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
load(rules) | rules: ConfigList | - | 加载转换规则
apply(str,[ret_org_str]) | str: string, ret_org_str: bool  | string | 转换字符串: 預設轉換失敗返回 空字串， ret_org_str: true 返回原字串 

使用参考： <https://github.com/hchunhui/librime-lua/pull/102>

```lua
local config = env.engine.schema.config
-- load ConfigList form path
local proedit_fmt_list = conifg:get_list("translator/preedit_format")
-- create Projection obj
local p1 = Projection()
-- load convert rules
p1:load(proedit_fmt_list)
-- convert string
local str_raw = "abcdefg"
local str_preedit = p1:apply(str)

-- new example
  local p2 = Projection(config:get_list('translator/preedit_format'))
  local p3 = Projection({'xlit/abc/ABC/', 'xlit/ABC/xyz/'})
   p3:apply(str,[true]) 

```

## Component

調用 processor, segmentor, translator, filter 組件，可在lua script中再重組。
參考範例: [librime-lua/sample/lua/component_test.lua](https://github.com/hchunhui/librime-lua/tree/master/sample/lua/component_test.lua)

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
Processor |engine, [schema, ]name_space, prescription |Processor | 如：`Component.Processor(env.engine, "", "ascii_composer")`, `Component.Processor(env.engine, Schema('cangjie5'), "", 'ascii_composer)`(使用Schema: cangjie5 config)
Segmentor |同上 | Segmentor|
Translator|同上 | Translator | `Component.Translator(env.engine, '', 'table_translator')
Filter | 同上 | Filter | `Component.Filter(env.engine, '', 'uniquility')`

## Processor

属性：

属性名 | 类型 | 解释
--- | --- | ---
name_space|string|取出instance name_space #212

方法:

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
process_key_event|KeyEvent|0-2| 0:kReject 1:kAccepted 2:Noop,[參考engine.cc](https://github.com/rime/librime/blob/9086de3dd802d20f1366b3080c16e2eedede0584/src/rime/engine.cc#L107-L111)

## Segmentator

属性：

属性名 | 类型 | 解释
--- | --- | ---
name_space|string|取出instance name_space #212

方法:

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
proceed|Segmentation|bool| [參考engine.cc](https://github.com/rime/librime/blob/9086de3dd802d20f1366b3080c16e2eedede0584/src/rime/engine.cc#L168)

## Translator

属性：

属性名 | 类型 | 解释
--- | --- | ---
name_space|string|取出instance name_space #212

方法:

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
query|string: input, segmet|Translation [參考engine.cc](https://github.com/rime/librime/blob/9086de3dd802d20f1366b3080c16e2eedede0584/src/rime/engine.cc#L189-L218)

## Filter

属性：

属性名 | 类型 | 解释
--- | --- | ---
name_space|string|取出instance name_space #212

方法:

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
apply|translation,cands|Translation|[參考engine.cc](https://github.com/rime/librime/blob/9086de3dd802d20f1366b3080c16e2eedede0584/src/rime/engine.cc#L189-L218)

## Notifier

接收通知

通知类型：
1. commit_notifier
2. select_notifier
3. update_notifier
4. delete_notifier

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法： notifier connect 

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
connect(func[,group]) | func: function grup: int | Notifier 新增 group 依 gorup 順序通知 0,1,...connect(func) 排在最後)|**使用 notifier 時必須在解構時 disconnect()** 


e.g.
```lua
-- ctx: Context
function init(env)
  env.notifier = env.engine.context.commit_notifier:connect(function(ctx)
  -- your code ...
end)
end
function fini(env)
   env.notifier:disconnect()
end
```

## OptionUpdateNotifier

同 Notifier

e.g.
```lua
-- ctx: Context
-- name: string
env.engine.context.option_update_notifier:connect(function(ctx, name)
  -- your code ...
end)
```

## PropertyUpdateNotifier

同 Notifier

e.g.
```lua
-- ctx: Context
-- name: string
env.engine.context.property_update_notifier:connect(function(ctx, name)
  -- your code ...
end)
```

## KeyEventNotifier

同 Notifier

e.g.
```lua
-- ctx: Context
-- key: KeyEvent
env.engine.context.unhandled_key_notifier:connect(function(ctx, key)
  -- your code ...
end)
```

## Connection

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
disconnect

## log

记录日志到日志文件

日志位置：<https://github.com/rime/home/wiki/RimeWithSchemata#%E9%97%9C%E6%96%BC%E8%AA%BF%E8%A9%A6>
+ 【中州韻】 `/tmp/rime.ibus.*`
+ 【小狼毫】 `%TEMP%\rime.weasel.*`
+ 【鼠鬚管】 `$TMPDIR/rime.squirrel.*`
+ 各發行版的早期版本 `用戶資料夾/rime.log`

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
info
warning
error

## rime_api

属性：

属性名 | 类型 | 解释
--- | --- | ---

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
get_rime_version | | string | librime 版本
get_shared_data_dir | | string | 程序目录\data
get_user_data_dir | | string | 用户目录
get_sync_dir | | string | 用户资料同步目录
get_distribution_name | | string | 如：“小狼毫”
get_distribution_code_name | | string | 如：“Weasel”
get_distribution_version | | string | 发布版本号
get_user_id

## CommitRecord

CommitRecord : 參考 librime/src/rime/ engine.cc commit_history.h 
* commit_text => `{type: 'raw', text: string}`
* commit => `{type: cand.type, text: cand.text}`
* reject => `{type: 'thru', text: ascii code}`

属性：

属性名 | 类型 | 解释
--- | --- | ---
type| string |
text| string |

## CommitHistory

engine 在 commit commit_text 會將 資料存入 commit_history, reject且屬於ascii範圍時存入ascii
此api 除了可以取出 CommitRecord 還可以在lua中推入commit_record
參考: librime/src/rime/gear/history_translator

属性：

属性名 | 类型 | 解释
--- | --- | ---
size| number| max_size <=20

方法：

方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
push|(KeyEvent), (composition, ctx.input) (cand.type, cand.text)| |推入 CommitRecord
back| | CommitRecord|取出最後一個 CommitRecord
to_table| | lua table of CommitRecord|轉出 lua table of CommitRecord
iter| | | reverse_iter
repr| | string| 格式 [type]text[type]text....
latest_text| | string | 取出最後一個CommitRecord.text
empty| | bool
clear| | | size=0
pop_back| | | 移除最後一個CommitRecord

```lua
-- 將comit cand.type == "table" 加入 translation
local T={}
function T.func(inp, seg, env)
  if not seg.has_tag('histroy') then return end

  for r_iter, commit_record in context.commit_history:iter() do
    if commit_record.type == "table" then
       yield(Candidate(commit_record.type, seg.start, seg._end, commit_record.text, "commit_history"))
    end
  end
end
return T
```

## DbAssessor 
支援 leveldb:query(prefix_key) 

methods: obj of LevelDb
 方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
reset| none | bool| jump to begin
jump | prefix of key:string|bool| jump to first of prefix_key 
iter | none | iter_func,self| 範例: for k, v in da:iter() do print(k, v) end

请注意， **`DbAccessor` 必须先于其引用的 `LevelDb` 对象释放，否则会导致输入法崩溃** ！ 由于目前 `DbAccessor` 没有封装析构接口，常规做法是将引用 `DbAccessor` 的变量置空，然后调用 `collectgarbage()` 来释放掉 `DbAccessor` 。

```lua
local da = db:query(code)
da = nil
collectgarbage() -- 确保 da 所引用的 DbAccessor 被释放
db:close()       -- 此时关闭 db 才是安全的，否则可能造成输入法崩溃
```
 
## LevelDb ( 不可用於已開啓的userdb, 專用於 librime-lua key-value db)

便於調用大型資料庫且不佔用 lua 動態記憶

### 新建 leveldb
 方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
LevelDb| dbname:string| obj of LevelDb| local db = LevelDb('ecdict') -- opendb :user_data_dir/ecdict 

### 物件方法
 方法名 | 参数 | 返回值 | 解释
--- | --- | --- | ---
open| none| bool| 
open_read_only| none| bool| 禁用 earse ,update
close| none| bool|
loaded| none| bool| 
query| prefix of key:string|obj of DbAccessor| 查找 prefix key 
fetch| key:string| value:string or nil| 查找 value
update| key:string,value:string|bool|
erase| key:string|bool|

範例：
```lua
 -- 建議加入 db_pool 可避免無法開啓已開啓DB
 _db_pool= _db_pool or {}
 local function wrapLevelDb(dbname, mode)
   _db_pool[dbname] = _db_pool[dbname] or LevelDb(dbname)
   local db = _db_pool[dbname]
   if db and not db:loaded() then
      if mode then
        db:open()
      else 
        db:open_read_only()
      end
      return db
   end
 end
 
 local db = wrapLevelDb('ecdict') -- open_read_only
 -- local db = wrapLevelDb('ecdictu', true) -- open
 local da = db:query('the') -- return obj of DbAccessor
 for k, v in da:iter() do print(k, v) end
```

请注意， **`DbAccessor` 必须先于其引用的 `LevelDb` 对象释放，否则会导致输入法崩溃** ！详见 `DbAccessor` 的说明。