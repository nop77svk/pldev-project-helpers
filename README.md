# PL/SQL Developer (Allround Automations) project file helper scripts

The PL/SQL Developer project files come with old-school INI-based structure with rather unfortunate project items assignment to item groups/folders based on positional ID. If an item (SQL/PLSQL script file) gets added/removed anywhere "in/from the middle" of the existing project items, all item groups/folders in the INI file are heavily rewritten with completely different item IDs due to their positional nature.

These project files are not easily manageable under a version control system. The problem is somewhat bearable when only one team member manages a project file - file can be committed anytime, although comparison of differences is perhaps of lesser use.

The problem gets more pronounced when there are multiple maintaners of the project file; and it gets completely unbearable as soon as branching/merging gets introduced to the solution which uses the PL/SQL Developer project files. Merging conflicts in these files could become your daily (or even hourly) routine.

Hence I coded my own few helper scripts around this (and a few others) problem.

merge_pldev_prj.sh
==================

A simple preprocess->process->postprocess shell script for merging the PL/SQL Developer project files. Run it, argument-less, from command line and see its simple usage help. I believe it's self-explanatory.

Before actually using this helper you may need to open the `merge_pldev_prj.sh` and edit the line that follows

    # set up path to the TortoiseMerge.exe here...

**Depends on:**
* `bash`, `gawk`, `sed`, `tr` (perhaps from https://www.cygwin.com/),
* `TortoiseMerge`,
* `dos2unix` utility for converting DOS/Win EOLNs (CR+LF) to Unix EOLNs (LF).

order_pldev_project_items.awk
=============================

Order project items alphabetically. It's great, though purely optional, before an actual merging.

Usage:

    gawk -f "${PathToPldevHelpers}/order_pldev_project_items.awk" < project_file.prj > project_file_ordered.prj

... or...

    dos2unix < project_file.prj | gawk -f "${PathToPldevHelpers}/order_pldev_project_items.awk" > project_file_ordered.prj

cross_check_PRJ_vs_filesystem.sh
================================

PL/SQL Developer does not check for existence of project items on the filesystem. Use this script to check all project files (*.prj) in your current directory for existence of their items on the filesystem *and vice versa*.

All project items that do not exist on filesystem, are automatically removed from the (resulting) project file.

All filesystem items (in the whole subtree of your "current directory") are automatically added into the (resulting) project file under the "unsorted" item group.

**Depends on:**
* `gawk`, `sed`, `egrep`, `tr`, `sort`, `find`, `comm` (perhaps from https://www.cygwin.com/)
