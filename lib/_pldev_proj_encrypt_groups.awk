BEGIN {
	section = "<header>";
	fileIndex = 0;
	sectionCounter = 0;
}

{
	sectionCounter++;
}

$0 ~ /^\s*\[.*?\]\s*$/ {
	if (currentSection == "GroupedFiles")
	{
		print "[Groups]";
		for (i in groupOrder) {
			groupName = groupOrder[i];
			print groupName "=" groups[groupName];
		}
		print "";

		print "[Files]";
		for (i in files)
			print files[i];
		print "";
	}

	currentSection = "";
	sectionCounter = 0;
}

currentSection == "GroupedFiles" && sectionCounter > 0 {
	match($0, /^group{(.*?)};item{(.*?)}$/, xx);

	groupName = xx[1];
	fileItem = xx[2];

	files[fileIndex] = fileItem;
	groups[groupName] = groups[groupName] fileIndex ",";

	fileIndex++;
}

currentSection == "GroupOrder" && sectionCounter > 0 {
	groupOrder[sectionCounter-1] = $0;
}

$0 ~ /^\s*\[.*?\]\s*$/ {
	match($0, /^\s*\[(.*?)\]\s*$/, xx);
	currentSection = xx[1];
}

currentSection != "GroupedFiles" && currentSection != "GroupOrder" {
	print;
}

