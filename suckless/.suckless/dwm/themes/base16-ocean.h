static const char normbordercolor[] = "#4f5b66";
static const char normbgcolor[]     = "#2b303b";
static const char normfgcolor[]     = "#4f5b66";

static const char selbordercolor[]  = "#8fa1b3";
static const char selbgcolor[]      = "#2b303b";
static const char selfgcolor[]      = "#a7adba";

static const char urgbordercolor[]  = "#f7f7f7"; // pending
static const char urgbgcolor[]      = "#2b303b";
static const char urgfgcolor[]      = "#bf616a";

/* custom */
static const char magenta[]         = "#b48ead";

static const char *colors[][4]      = {
	/*               fg         bg         border   */
    [SchemeNorm] = { normfgcolor,   normbgcolor,   normbordercolor, },
    [SchemeSel]  = { selfgcolor,    selbgcolor,    selbordercolor, },
	[SchemeUrg] =  { urgfgcolor,    urgbgcolor,    urgbordercolor },
	/* Custom colors */
	[SchemeRandom] =  { urgfgcolor,    urgbgcolor,    urgbordercolor },
};

