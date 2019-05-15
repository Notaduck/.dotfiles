
const char *colorname[] = {
 	/* 8 normal colors */
	/* "#EDEDED", */
	/* "#969694", */
	/* "#D7005F", */
	/* "#D7005F", */
	/* "#718C00", */
	/* "#718C00", */
	/* "#D75F00", */
	/* "#D75F00", */

 	/* /1* 8 bright colors *1/ */
	/* "#424242", */
	/* "#e83b3f", */
	/* "#7aba3a", */
	/* "#ffea2e", */
	/* "#54a4f3", */
	/* "#aa4dbc", */
	/* "#26bbd1", */
	/* "#d9d9d9", */
 

	"#262626", 
	"#262626", 
	"#4d4d4c", 
	"#808080", 
	"#949494", 
	"#d0d0d0", 
	"#f3f3f3", 
	"#f3f3f3", 
	"#8959a8",
	"#d75f00",
	"#4271ae",
	"#718c00",
	"#3e999f",
	"#005f87",
	"#d7005f",
	"#df0000",
 	[255] = 0,
 
 	/* more colors can be added after 255 to use with DefaultXX */
	"#e5e5e5",
  "#232322",
};


/*
* Default colors (colorname index)
* foreground, background, cursor, reverse
* cursor
*/
unsigned int defaultfg = 256;
unsigned int defaultbg = 257;
unsigned int defaultcs = 256; /* nord4 */
unsigned int defaultrcs = 8;  /* nord3 */
