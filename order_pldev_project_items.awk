BEGIN {
	state = "";
	findex = 0;
	gindex = 0;

	FS = ",";
}

# ----------------------------------------------------------------------------

$0 == "" && state == "files" {
	for (i=0; i<findex; i++) {
		itemFName = items[i, "fname"];

		itemIndex[itemFName] = i;
		itemFullLine[itemFName] = items[i, "fitem"];
		itemGroup[itemName] = items[i, "group"];

		item[itemFName "::" i]["index"] = i;
		item[itemFName "::" i]["line"] = items[i, "fitem"];
		item[itemFName "::" i]["group"] = items[i, "group"];
	}

	asorti(item, itemSorted);

	for (i in itemSorted) {
		fnIndex = itemSorted[i];
		newItem[i, "origIndex"] = item[fnIndex]["index"];
		newItem[i, "line"] = item[fnIndex]["line"];
		newItem[i, "group"] = item[fnIndex]["group"];

		groupName = newItem[i, "group"];
		groupDef[groupName] = groupDef[groupName] (i-1) ",";
	}

	print "[Groups]";
	for (i=1; i<=gindex; i++)
		if (groups[i] != "")
			print groups[i] "=" groupDef[groups[i]];

	print "";
	print "[Files]";
	for (i=1; i<=findex; i++)
		print newItem[i, "line"];
}

# ----------------------------------------------------------------------------

$0 == "" && state != "" {
	state = "";
}

state == "" && $0 != "[Groups]" && $0 != "[Files]" {
	print;
}

# ----------------------------------------------------------------------------
# group:
# enums=11,13,14,15,16,26,38,41,43,55,65,68,69,70,76,82,90,106,110,111,126,127,132,155,
# file:
# 3,4,,,EWS\sql\utl_dd_intfc_file.pck

state == "groups" {
	match($0, /^([^=]+)=(.*)/, xx);
	groupName = xx[1];
	gindex++;
	groups[gindex] = groupName;
	groupDef[groupName] = "";

	$0 = xx[2];

	for (i=1; i<=NF; i++)
		if ($i != "") {
			j = $i;
			items[j, "fname"] = "";
			items[j, "fitem"] = "";
			items[j, "group"] = groupName;
		}
}

state == "files" {
	FS = ",";

	match($5, /[^\\]*$/, xx);
	fname = xx[0];

	fitem = $0;

	items[findex, "fname"] = fname;
	items[findex, "fitem"] = fitem;

	findex++;
}

# ----------------------------------------------------------------------------

$0 == "[Groups]" && state == "" {
	state = "groups"
}

$0 == "[Files]" && state == "" {
	state = "files"
}
