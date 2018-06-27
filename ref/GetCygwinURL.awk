BEGIN {
	InItem = 0;
	unormal = 0;
	ItemName = "";
	Line = 0;
	ORS = "\r\n";
	printf("<HTML>\r\n<HEAD>\r\n<TITLE>CYGWIN PACKAGE URL</TITLE>\r\n");
	printf("<BASE href=\"http://mirrors.sunsite.dk/cygwin/\">\r\n");
	printf("</HEAD>\r\n<BODY>\r\n");
    }
$1 == "@" {
	if (InItem) {
		unormal++;
		print "Warning: Line " Line ":", ItemName, ": No install package." | "cat 1>&2";
	}
	InItem = 1;
	ItemName = $2;
	Line = NR;
	next;
    }
InItem == 1 && $1 == "version:" {
	Version = $2 $3 $4 $5 $6;
	next;
    }    
InItem == 1 && $1 == "install:" {
	print "<a href=" $2 ">" ItemName " " Version "</a><br>";
	InItem = 0;
    }
END {
	print "</BODY>" ORS "</HTML>"
	print "Total Warning: " unormal | "cat 1>&2";
    }