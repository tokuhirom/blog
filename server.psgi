use strict;
use Plack::Builder;
use Plack::App::File;
use Path::Class;
use Plack::Loader;

my $ROOT = '.';

do 'blog.pl';
my $file = Plack::App::File->new({ root => '.' });

my $app = sub {
    my $env  = shift;
    my $path = $env->{PATH_INFO};
    if ($path eq '/' || $path =~ /\.html/) {
        TGP->run();
    }
    if ( -d dir( $ROOT, $path ) ) {
        if ( $path !~ m{/$} ) {
            return [ 302, [ Location => "$path/" ], [] ];
        }
        else {
            $path .= "/index.html";
        }
    }
    return $file->call( { %$env, PATH_INFO => $path } );
}

