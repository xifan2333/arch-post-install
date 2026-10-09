/* See LICENSE file for copyright and license details. */
#include <X11/XF86keysym.h>

/* appearance */
static unsigned int borderpx         = 2;    /* border pixel of windows */
static unsigned int gappx            = 4;    /* gaps between windows */
static unsigned int snap             = 32;   /* snap pixel */
static int showbar                   = 1;    /* 0 means no bar */
static int topbar                    = 1;    /* 0 means bottom bar */
static const int refreshrate         = 120;  /* refresh rate for client move/resize */
static const char *fonts[]           = { "monospace:size=10" };
static const char dmenufont[]        = "monospace:size=10";
static const char col_gray1[]        = "#222222";
static const char col_gray2[]        = "#444444";
static const char col_gray3[]        = "#bbbbbb";
static const char col_gray4[]        = "#eeeeee";
static const char col_cyan[]         = "#005577";
static const char *colors[][3] = {
	/*               fg         bg         border   */
	[SchemeNorm] = { col_gray3, col_gray1, col_gray2 },
	[SchemeSel]  = { col_gray4, col_cyan,  col_cyan  },
};

/* tagging */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
	/* xprop(1):
	 *	WM_CLASS(STRING) = instance, class
	 *	WM_NAME(STRING) = title
	 */
	/* class      instance    title       tags mask     isfloating   monitor */
	{ "Gimp",     NULL,       NULL,       0,            1,           -1 },
	{ "Firefox",  NULL,       NULL,       1 << 8,       0,           -1 },
};

/* layout(s) */
static float mfact           = 0.55; /* factor of master area size [0.05..0.95] */
static int nmaster           = 1;    /* number of clients in master area */
static int resizehints       = 1;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */

static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },    /* first entry is default */
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* key definitions */
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static char dmenumon[2] = "0"; /* component of dmenucmd, manipulated in spawn() */
static char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-fn", "monospace:size=10", "-nb", "#222222", "-nf", "#bbbbbb", "-sb", "#005577", "-sf", "#eeeeee", NULL };
static const char *termcmd[]  = { "st", NULL };

static const Key keys[] = {
	/* modifier                     key                       function        argument */
	/* 1. Core Applications (aligned with Wayland: Return = terminal, Space = launcher) */
	{ MODKEY,                       XK_Return,                spawn,          {.v = termcmd } },
	{ MODKEY|ShiftMask,             XK_Return,                zoom,           {0} },
	{ MODKEY,                       XK_space,                 spawn,          {.v = dmenucmd } },
	{ MODKEY,                       XK_p,                     togglefloating, {0} },
	{ MODKEY|ShiftMask,             XK_space,                 togglefloating, {0} },

	/* 2. Window Lifecycle (Q/W = close, F = fullscreen) */
	{ MODKEY,                       XK_q,                     killclient,     {0} },
	{ MODKEY,                       XK_w,                     killclient,     {0} },
	{ MODKEY|ShiftMask,             XK_c,                     killclient,     {0} },
	{ MODKEY,                       XK_f,                     togglefullscr,  {0} },
	{ MODKEY|ShiftMask,             XK_f,                     togglefullscr,  {0} },

	/* 3. Session & Tools (Power menu, screenshots) */
	{ MODKEY|ShiftMask,             XK_Escape,                spawn,          SHCMD("custom-power") },
	{ 0,                            XK_Print,                 spawn,          SHCMD("custom-capture area") },
	{ ShiftMask,                    XK_Print,                 spawn,          SHCMD("custom-capture full") },
	{ MODKEY,                       XK_Print,                 spawn,          SHCMD("custom-capture") },
	{ MODKEY|ShiftMask,             XK_s,                     spawn,          SHCMD("custom-capture edit") },

	/* 4. Hardware Multimedia & Volume Keys */
	{ 0,                            XF86XK_AudioRaiseVolume,  spawn,          SHCMD("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+") },
	{ 0,                            XF86XK_AudioLowerVolume,  spawn,          SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") },
	{ 0,                            XF86XK_AudioMute,         spawn,          SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
	{ 0,                            XF86XK_AudioMicMute,      spawn,          SHCMD("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") },
	{ 0,                            XF86XK_MonBrightnessUp,   spawn,          SHCMD("brightnessctl set +5%") },
	{ 0,                            XF86XK_MonBrightnessDown, spawn,          SHCMD("brightnessctl set 5%-") },
	{ 0,                            XF86XK_AudioPlay,         spawn,          SHCMD("playerctl play-pause") },
	{ 0,                            XF86XK_AudioNext,         spawn,          SHCMD("playerctl next") },
	{ 0,                            XF86XK_AudioPrev,         spawn,          SHCMD("playerctl previous") },

	/* 5. Navigation & Layouts */
	{ MODKEY,                       XK_b,                     togglebar,      {0} },
	{ MODKEY,                       XK_j,                     focusstack,     {.i = +1 } },
	{ MODKEY,                       XK_k,                     focusstack,     {.i = -1 } },
	{ MODKEY,                       XK_i,                     incnmaster,     {.i = +1 } },
	{ MODKEY,                       XK_d,                     incnmaster,     {.i = -1 } },
	{ MODKEY,                       XK_h,                     setmfact,       {.f = -0.05} },
	{ MODKEY,                       XK_l,                     setmfact,       {.f = +0.05} },
	{ MODKEY,                       XK_Tab,                   view,           {0} },
	{ MODKEY,                       XK_t,                     setlayout,      {.v = &layouts[0]} },
	{ MODKEY,                       XK_m,                     setlayout,      {.v = &layouts[2]} },
	{ MODKEY|ControlMask,           XK_space,                 setlayout,      {0} },
	{ MODKEY,                       XK_0,                     view,           {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,                     tag,            {.ui = ~0 } },
	{ MODKEY,                       XK_comma,                 focusmon,       {.i = -1 } },
	{ MODKEY,                       XK_period,                focusmon,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_comma,                 tagmon,         {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_period,                tagmon,         {.i = +1 } },
	{ MODKEY,                       XK_F5,                    xresreload,     {0} },
	{ MODKEY,                       XK_minus,                 setgaps,        {.i = -1 } },
	{ MODKEY,                       XK_equal,                 setgaps,        {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_equal,                 setgaps,        {.i = 0  } },
	TAGKEYS(                        XK_1,                                     0)
	TAGKEYS(                        XK_2,                                     1)
	TAGKEYS(                        XK_3,                                     2)
	TAGKEYS(                        XK_4,                                     3)
	TAGKEYS(                        XK_5,                                     4)
	TAGKEYS(                        XK_6,                                     5)
	TAGKEYS(                        XK_7,                                     6)
	TAGKEYS(                        XK_8,                                     7)
	TAGKEYS(                        XK_9,                                     8)
	{ MODKEY|ShiftMask,             XK_q,                     quit,           {0} },
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
	/* click                event mask      button          function        argument */
	{ ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
	{ ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[2]} },
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} },
	{ ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
	{ ClkTagBar,            0,              Button1,        view,           {0} },
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
};

/* X resources to update */
static const XResPref resources[] = {
	/* name                type     address */
	{ "dwm.font",          STRING,  &fonts[0] },
	{ "dwm.dmenufont",     STRING,  &dmenucmd[4] },
	{ "dwm.background",    STRING,  &dmenucmd[6] },
	{ "dwm.foreground",    STRING,  &dmenucmd[8] },
	{ "dwm.backgroundSel", STRING,  &dmenucmd[10] },
	{ "dwm.foregroundSel", STRING,  &dmenucmd[12] },
	{ "dwm.foreground",    STRING,  &colors[SchemeNorm][ColFg] },
	{ "dwm.background",    STRING,  &colors[SchemeNorm][ColBg] },
	{ "dwm.border",        STRING,  &colors[SchemeNorm][ColBorder] },
	{ "dwm.foregroundSel", STRING,  &colors[SchemeSel][ColFg] },
	{ "dwm.backgroundSel", STRING,  &colors[SchemeSel][ColBg] },
	{ "dwm.borderSel",     STRING,  &colors[SchemeSel][ColBorder] },
	{ "dwm.borderpx",      INTEGER, &borderpx },
	{ "dwm.snap",          INTEGER, &snap },
	{ "dwm.showbar",       INTEGER, &showbar },
	{ "dwm.topbar",        INTEGER, &topbar },
	{ "dwm.nmaster",       INTEGER, &nmaster },
	{ "dwm.resizehints",   INTEGER, &resizehints },
	{ "dwm.mfact",         FLOAT,   &mfact },
};
