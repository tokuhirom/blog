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
use List::UtilsBy qw(nsort_by);
use Log::Minimal;

has xslate => (
    is => 'rw',
    default => sub {
        Text::Xslate->new(
            syntax => 'TTerse',
            module => ['Text::Xslate::Bridge::TT2Like'],
            path => ['tmpl'],
            cache => 0,
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

sub git_mtime {
    # system(q[git log --name-only --date=iso --reverse --pretty=format:%at "$@" | perl -00ln -e '($d,@f)=split/\n/;$d{$_}=$d for grep{-e $_ && m{^_source}}@f' -e '}{utime undef,$d{$_},$_ for keys%d']);
}

sub run {
    my $self = shift;
    $self->git_mtime();

    my @files = nsort_by { $_->ctime } map { Entry->new(file => $_) } glob('_source/*.txt');

    $self->render_index([grep { $_ } @files[0..10]]);
    # TODO: rss
    # TODO: entry page
}

sub render_index {
    my ($self, $entries) = @_;
    $self->render('index.html', 'index.tt', { entries => $entries, c => $self });
}

sub render {
    my ($self, $dest, $tmpl, $params) = @_;
    infof("rendering $dest");
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

has content => (
    is => 'rw',
    isa => 'Str',
);

has title => (
    is => 'rw',
    isa => 'Str',
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
);
$engine->run();

sub TGP::run {
    my $engine = Engine->new(
        title => "tokuhirom's blog",
    );
    $engine->run();
}

# TODO: cache?
# TODO: permalink
# TODO: rss
