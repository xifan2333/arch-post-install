/* ========================================================
   wayhud 样式表 (~/.config/wayhud/style.css)
   由 x-theme 模板系统生成，自动同步全局语义主题
   ======================================================== */

/* 1. 基础公共样式 */
window {
    background-color: {{ dark_background }}dd;
    border-radius: 8px;
    border: 1px solid {{ accent }}33;
}

label {
    font-family: "JetBrainsMono Nerd Font";
    text-shadow: none;
}

/* 2. 场景：按键回显 (#keys) - 左下角紧凑，按内容自适应，1.2s 消隐 */
window#keys {
    margin-bottom: 195px;
    margin-left: 4px;
    max-width: 220px;
    padding: 6px 12px;
    transition-duration: 1.2s;
}

label#keys {
    font-size: 16px;
    color: {{ foreground }};
}

/* 3. 场景：直播/屏幕标题 (#title) - 屏幕顶端 Waybar 下方居中大横条，永久常驻 (0) */
window#title {
    margin-top: 36px;
    min-width: 600px;
    max-width: 1000px;
    padding: 6px 20px;
    background-color: {{ darker_background }}ee;
    border-radius: 20px;
    border: 1px solid {{ accent }}66;
    transition-duration: 0;
}

label#title {
    font-size: 15px;
    color: {{ accent }};
    text-align: center;
}

/* 4. 场景：实时字幕 (#captions) - 底部大宽度，水平居中折行 */
window#captions {
    margin-bottom: 36px;
    min-width: 500px;
    max-width: 800px;
    padding: 8px 20px;
    border-radius: 12px;
    background-color: {{ dark_background }}e6;
    border: 1px solid {{ green }}55;
    transition-duration: 2.5s;
}

label#captions {
    font-size: 18px;
    color: {{ green }};
    text-align: center;
}
