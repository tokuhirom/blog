#!/bin/sh
git log --name-only --date=iso --reverse --pretty=format:%at "$@" | perl -00ln -e '($d,@f)=split/\n/;$d{$_}=$d for grep{-e $_ && m{^_source}}@f' -e '}{utime undef,$d{$_},$_ for keys%d'
