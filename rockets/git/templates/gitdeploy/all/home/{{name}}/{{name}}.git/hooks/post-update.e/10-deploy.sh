#!/bin/sh
#
# This hook does two things:
#
#  1. update the "info" files that allow the list of references to be
#     queries over dumb transports such as http
#
#  2. if this repository looks like it is a non-bare repository, and
#     the checked-out branch is pushed to, then update the working copy.
#     This makes "push" function somewhat similarly to darcs and bzr.
#
# To enable this hook, make this file executable by "chmod +x post-update".

git-update-server-info

is_bare=$(git-config --get --bool core.bare)


if [ -z "$is_bare" ]
then
	# for compatibility's sake, guess
	git_dir_full=$(cd $GIT_DIR; pwd)
	case $git_dir_full in */.git) is_bare=false;; *) is_bare=true;; esac
fi

update_wc() {
	ref=$1
	if (cd $GIT_WORK_TREE; git-diff-files -q --exit-code >/dev/null)
	then
		wc_dirty=0
	else
		echo "W:unstaged changes found in working copy" >&2
		wc_dirty=1
		desc="working copy"
	fi
	if git diff-index --cached HEAD@{1} >/dev/null
	then
		index_dirty=0
	else
		echo "W:uncommitted, staged changes found" >&2
		index_dirty=1
		if [ -n "$desc" ]
		then
			desc="$desc and index"
		else
			desc="index"
		fi
	fi
	if [ "$wc_dirty" -ne 0 -o "$index_dirty" -ne 0 ]
	then
		new=$(git rev-parse HEAD)
		echo "W:stashing dirty $desc - see git-stash(1)" >&2
		( trap 'echo trapped $$; git symbolic-ref HEAD "'"$ref"'"' 2 3 13 15 ERR EXIT
		git-update-ref --no-deref HEAD HEAD@{1}
		cd $GIT_WORK_TREE
		git stash save "dirty $desc before update to $new";
		git-symbolic-ref HEAD "$ref"
		)
	fi

	# eye candy - show the WC updates :)
	echo "Updating working copy" >&2
	(cd $GIT_WORK_TREE
	git-diff-index -R --name-status HEAD >&2
	git-reset --hard HEAD)
}

if [ "$is_bare" = "false" ]
then
	active_branch=`git-symbolic-ref HEAD`
	export GIT_DIR=$(cd $GIT_DIR; pwd)
	GIT_WORK_TREE=${GIT_WORK_TREE-..}
	for ref
	do
		if [ "$ref" = "$active_branch" ]
		then
			update_wc $ref
		fi
	done
fi

