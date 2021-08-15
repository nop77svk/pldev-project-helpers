BEGIN {
	section = "<header>";
	fileIndex = 0;
	sectionCounter = 0;
}

{
	sectionCounter++;
}

$0 ~ /^\s*\[.*?\]\s*$/ {
	currentSection = "";
}

currentSection == "Groups" && ! ( $0 ~ /^\s*$/ ) {
	match($0, /^\s*([^=]*?)\s*=\s*(.*?)\s*$/, xx);
	groupName = xx[1];
	groupItems = xx[2];

	print groupName;

	split(groupItems, yy, /\s*,\s*/);
	for(ii in yy)
		itemGroup[yy[ii]] = groupName;
}

currentSection == "Files" && ! ( $0 ~ /^\s*$/ ) {
	print "group{" itemGroup[fileIndex] "};item{" $0 "}";
	fileIndex++;
}

$0 ~ /^\s*\[.*?\]\s*$/ {
	match($0, /^\s*\[(.*?)\]\s*$/, xx);
	currentSection = xx[1];
	sectionCounter = 0;
}

currentSection == "Groups" && sectionCounter == 0 {
	print "[GroupOrder]";
}

currentSection == "Files" && sectionCounter == 0 {
	print "[GroupedFiles]";
}

currentSection != "Files" && currentSection != "Groups" {
	print;
}
