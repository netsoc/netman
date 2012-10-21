#!/bin/bash

BASEURL="https://wiki.netsoc.tcd.ie/index.php"
DIRECTORY="/var/local/netman/man"

function page2man {
	PAGE="$1"
	
	echo "Converting $page" 1>&2	

	echo '.pc' # dunno what this does, but it was in 'man man', so I put it here
	echo -n '.TH MAN 9 "'   # Title start, 9 because it's never used

	# Get modified date for title
	wget "$BASEURL?title=$PAGE" -O- 2>/dev/null |
	grep 'This page was last modified on' | sed 's/^.*modified on \(.*\)\.<.*$/\1/g' | tr -d '\n'

	# Finish title
	echo "\" \"\" \"$PAGE\""

	echo ".SH Wiki URL:"
	echo "https://wiki.netsoc.tcd.ie/index.php?title=$PAGE"
	echo -e ".br\n.br\n.SH Content:"

	
	# This block is where the actual wiki content is inserted
	wget "$BASEURL?title=$PAGE&action=raw" -O- 2>/dev/null | 
	sed -e '
	s/^=\([^=]*\)=$/.SH \1/g                   # For top level headings
	s/^==\([^=]*\)==$/.SS \1/g                 # For Sub-headings
	s/^=\+\([^=]*\)=\+$/.HP\n.B \1\n.br/g      # For all other sub-sub headings
	
	s/<br\/>/\n.br/g                           # Turn <br/> into newlines
	s/<\/\?blockquote>//g                      # Remove <blockquote> tags
	s/^ *\*\(.*\)$/\\(bu \1\n/' |              # makes bullet points work

	# This bit is perl as we need non-greedy regex	
	perl -pe "
	s|'''(.*?)''' ?\.?|\\n.B \"\1\"\\n|g;      # emboldens text
	s|''(.*?)'' ?\.?|\\n.I \"\1\"\\n|g;        # italicises(actually underlines) text
	s|\[\[(.*?)\]\] ?\.?|\\n.I \"\1\"\\n|g;    # underline links to other articles
	
	s|<code>(.*?)</code> ?\.?|\n.I \"\1\"\n|g; # Underlines <code> sections
	s|<tt>(.*?)</tt> ?\.?|\n.I \"\1\"\n|g"     # same as above, but for <tt>
}

function getpages {
	lynx -dump "$BASEURL?title=Special:AllPages" | grep -oh "$BASEURL?title=[^:]*$" | uniq | sed 's/^[^=]*=//'
}


# Prints redirect target, or nothing if proper page
function isredirect {
	PAGE="$1"
	temp=$(wget "$BASEURL?title=$PAGE&action=raw" -O- 2>/dev/null | head -n 1 | grep '#REDIRECT' |
		perl -pe 's|^#REDIRECT \[\[(.*?)\]\]$|\1|g' | sed -e 's/#.*$//' -e 's/ /_/g')
	echo "${temp[@]^}" # capitalise first letter. No idea how this works
}


# Places a man page in the current directory for every page on the wiki
function go {
	for page in `getpages`; do
		real=`isredirect "$page"`
		if [ -z "$real" ]; then
			page2man "$page" > "$page.9"
		else
			ln -s "$real.9" "$page.9"
		fi
	done
	find "$DIRECTORY/" -type l ! -exec test -r {} \; -exec unlink {} \; # remove broken redirects
}

page2man Snark

umask 022
cd $DIRECTORY
rm *.9 2>/dev/null

go

git add .
git commit -am "`date`"







