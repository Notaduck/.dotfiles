
static const char *colorname[] = {
  "#282c34", /* 0: black */
  "#e06c75", /* 1: red */
  "#98c379", /* 2: green */
  "#d19a66", /* 3: yellow */
  "#61afef", /* 4: blue */
  "#c678dd", /* 5: magenta */
  "#56b6c2", /* 6: cyan */
  "#abb2bf", /* 7: white */
  "#5c6370", /* 8: brblack */
  "#e06c75", /* 9: brred */
  "#98c379", /* 10: brgreen */
  "#d19a66", /* 11: bryellow */
  "#61afef", /* 12: brblue */
  "#c678dd", /* 13: brmagenta */
  "#56b6c2", /* 14: brcyan */
  "#ffffff", /* 15: brwhite */
};

/*
 * Default colors (colorname index)
 * foreground, background, cursor, reverse cursor
 */
unsigned int defaultfg = 7;
unsigned int defaultbg = 0;
static unsigned int defaultcs = 7;
static unsigned int defaultrcs = 0;
