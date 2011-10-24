use strict;
use warnings;
use utf8;
use 5.010000;

package Engine;
use Mouse;
use Text::Xslate;
use Text::Xslate::Bridge::TT2Like;
use autodie ':all';
use File::stat;
use List::UtilsBy qw(rev_nsort_by);
use Log::Minimal;
use File::Basename qw(basename);
use XML::Feed;

our $CURRENT_TMPL;

has xslate => (
    is => 'rw',
    default => sub {
        Text::Xslate->new(
            syntax => 'TTerse',
            module => ['Text::Xslate::Bridge::TT2Like'],
            path => ['tmpl'],
            cache => 0,
            function => {
                uri_for => sub {
                    my $u = shift;
                    $CURRENT_TMPL eq 'entry.tt' ? "../$u" : $u;
                }
            },
        );
    },
);

has xatena => (
    is => 'rw',
    default => sub {
        Text::Xatena->new(
        );
    },
);

has title => (
    is => 'ro',
    default => sub {
        'myblog'
    }
);

has base => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

sub git_mtime {
    # system(q[git log --name-only --date=iso --reverse --pretty=format:%at "$@" | perl -00ln -e '($d,@f)=split/\n/;$d{$_}=$d for grep{-e $_ && m{^_source}}@f' -e '}{utime undef,$d{$_},$_ for keys%d']);
}

sub run {
    my $self = shift;
    $self->git_mtime();

    my @files = rev_nsort_by { $_->ctime } map { Entry->new(file => $_) } glob('_source/*.txt');

    for (@files) {
        $self->render_entry($_);
    }
    $self->render_index([grep { $_ } @files[0..10]]);
    $self->render_rss([grep { $_ } @files[0..10]]);
    # TODO: rss
    # TODO: entry page
}

sub render_rss {
    my ($self, $entries) = @_;

    infof("writing index.rss");
    my $feed = XML::Feed->new('RSS');
    $feed->title($self->title);
    $feed->link($self->base);
    for my $entry (@$entries) {
        my $e = XML::Feed::Entry->new();
        $e->title($entry->title);
        $e->link($self->base . '/entry/' . $entry->moniker);
        $e->content($entry->html);
        $feed->add_entry($e);
    }
    open my $fh, '>:utf8', 'index.rss';
    print {$fh} $feed->as_xml;
    close $fh;
}

sub render_index {
    my ($self, $entries) = @_;
    $self->render('index.html', 'index.tt', { entries => $entries, c => $self });
}

sub render_entry {
    my ($self, $entry) = @_;
    my $dst = $entry->moniker;
    $self->render( "entry/${dst}.html", 'entry.tt',
        { entry => $entry, c => $self } );
}

sub render {
    my ($self, $dest, $tmpl, $params) = @_;
    infof("rendering $dest");
    local $CURRENT_TMPL = $tmpl;
    my $html = $self->xslate->render($tmpl, $params);
    open my $fh, '>:utf8', $dest;
    print {$fh} $html;
    close $fh;
}

package Entry;
use Mouse;
use Text::Xatena;
use autodie;
use File::stat;
use Text::Xslate qw(mark_raw);
use Log::Minimal;
use Time::Piece;
use File::Basename qw(basename);

has file => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

for my $meth (qw(mtime ctime)) {
    has $meth => (
        is => 'ro',
        isa => 'Int',
        lazy => 1,
        default => sub {
            stat(shift->file)->$meth
        }
    );
}

has mtime_piece => (
    is => 'ro',
    default => sub {
        Time::Piece->new(shift->mtime)
    },
    lazy => 1,
);
has ctime_piece => (
    is => 'ro',
    default => sub {
        Time::Piece->new(shift->ctime)
    },
    lazy => 1,
);

has content => (
    is => 'rw',
    isa => 'Str',
);

has title => (
    is => 'rw',
    isa => 'Str',
);

has moniker => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $dst = basename($self->file);
        $dst =~ s/\..+//;
        return $dst;
    }
);

use Text::Xatena::Node::SuperPre;
has html => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        local $Text::Xatena::Node::SuperPre::SUPERPRE_CLASS_NAME = 'prettyprint';
        my $xatena = Text::Xatena->new();
        my $html = $xatena->format($self->content);
        mark_raw($html);
    },
);

sub BUILD {
    my $self = shift;

    open my $fh, '<:utf8', $self->file;
    $self->title(scalar <$fh>);
    $self->content(do { local $/; <$fh> });
}

package main;

my $engine = Engine->new(
    title => "tokuhirom's blog",
    base => 'http://tokuhirom.github.com/blog',
);
$engine->run();

sub TGP::run {
    my $engine = Engine->new(
        title => "tokuhirom's blog",
        base => 'http://tokuhirom.github.com/blog',
    );
    $engine->run();
}

# TODO: cache?
# TODO: permalink
# TODO: rss
