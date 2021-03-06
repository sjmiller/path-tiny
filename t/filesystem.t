use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Fatal;
use File::Temp qw(tmpnam tempdir);
use File::Spec;

use Path::Tiny;

# Tests adapted from Path::Class t/basic.t

my $file = path( scalar tmpnam() );
ok $file, "Got a filename via tmpnam()";

{
    my $fh = $file->openw;
    ok $fh, "Opened $file for writing";

    ok print( $fh "Foo\n" ), "Printed to $file";
}

ok -e $file, "$file should exist";
ok $file->is_file, "it's a file!";
my ( $volume, $dirname, $basename ) =
  map { s{\\}{/}; $_ } File::Spec->splitpath($file);
is( $file->volume,   $volume,   "volume correct" );
is( $file->volume,   $volume,   "volume cached " );  # for coverage
is( $file->dirname,  $dirname,  "dirname correct" );
is( $file->basename, $basename, "basename correct" );

{
    my $fh = $file->openr;
    is scalar <$fh>, "Foo\n", "Read contents of $file correctly";
}

{
    my $stat = $file->stat;
    ok $stat;
    cmp_ok $stat->mtime, '>', time() - 20;           # Modified within last 20 seconds

    $stat = $file->parent->stat;
    ok $stat;
}

1 while unlink $file;
ok not -e $file;

my $dir = path( tempdir( TMPDIR => 1, CLEANUP => 1 ) );
ok $dir;
ok -d $dir;
ok $dir->is_dir, "It's a directory!";

$file = $dir->child('foo.x');
$file->touch;
ok -e $file;
utime time - 10, time - 10, $file;
$file->touch;
ok( $file->stat->mtime > ( time - 10 ), "touch sets utime" );

{
    my @files = $dir->children;
    is scalar @files, 1 or diag explain \@files;
    ok scalar grep { /foo\.x/ } @files;
}

ok $dir->remove, "Removed $dir";
ok !-e $dir, "$dir no longer exists";
ok $dir->remove, "Removing non-existent dir returns true";

my $tmpdir = Path::Tiny->tempdir;

{
    $dir = path( $tmpdir, 'foo', 'bar' );
    $dir->parent->remove if -e $dir->parent;

    ok $dir->mkpath, "Created $dir";
    ok -d $dir, "$dir is a directory";

    $dir = $dir->parent;
    ok $dir->remove( { safe => 1 } ); # check that we pass through args
    ok !-e $dir;
}

{
    $dir = path( $tmpdir, 'foo' );
    ok $dir->mkpath;
    ok $dir->child('dir')->mkpath;
    ok -d $dir->child('dir');

    ok $dir->child('file.x')->touch;
    ok $dir->child('0')->touch;
    my @contents;
    my $iter = $dir->iterator;
    while ( my $file = $iter->() ) {
        push @contents, $file;
    }
    is scalar @contents, 3
      or diag explain \@contents;
    is( $iter->(), undef, "exhausted iterator is undef" );

    my $joined = join ' ', sort map $_->basename, grep { -f $_ } @contents;
    is $joined, '0 file.x'
      or diag explain \@contents;

    my ($subdir) = grep { $_ eq $dir->child('dir') } @contents;
    ok $subdir;
    is -d $subdir, 1;

    my ($file) = grep { $_ eq $dir->child('file.x') } @contents;
    ok $file;
    is -d $file, '';

    ok $dir->remove;
    ok !-e $dir;

    # Try again with directory called '0', in curdir
    my $orig = path()->absolute;

    ok $dir->mkpath;
    ok chdir($dir);
    my $dir2 = path();
    ok $dir2->child('0')->mkpath;
    ok -d $dir2->child('0');

    @contents = ();
    $iter     = $dir2->iterator;
    while ( my $file = $iter->() ) {
        push @contents, $file;
    }
    ok grep { $_ eq '0' } @contents;

    ok chdir($orig);
    ok $dir->remove;
    ok !-e $dir;
}

{
    my $file = path( $tmpdir, 'slurp' );
    ok $file;

    my $fh = $file->openw or die "Can't create $file: $!";
    print $fh "Line1\nLine2\n";
    close $fh;
    ok -e $file;

    my $content = $file->slurp;
    is $content, "Line1\nLine2\n";

    my @content = $file->lines;
    is_deeply \@content, [ "Line1\n", "Line2\n" ];

    @content = $file->lines( { chomp => 1 } );
    is_deeply \@content, [ "Line1", "Line2" ];

    ok( $file->remove, "removing file" );
    ok !-e $file, "file is gone";
    ok $file->remove, "removing file again returns true";
}

{
    my $file = path( $tmpdir, 'slurp' );
    ok $file;

    my $fh = $file->openw(':raw') or die "Can't create $file: $!";
    print $fh "Line1\r\nLine2\r\n\302\261\r\n";
    close $fh;
    ok -e $file;

    my $content = $file->slurp( { binmode => ':raw' } );
    is $content, "Line1\r\nLine2\r\n\302\261\r\n", "slurp raw";

    my $line3 = "\302\261\n";
    utf8::decode($line3);

    $content = $file->slurp( { binmode => ':crlf:utf8' } );
    is $content, "Line1\nLine2\n" . $line3, "slurp+crlf+utf8";

    my @content = $file->lines( { binmode => ':crlf:utf8' } );
    is_deeply \@content, [ "Line1\n", "Line2\n", $line3 ], "lines+crlf+utf8";

    chop($line3);
    @content = $file->lines( { chomp => 1, binmode => ':crlf:utf8' } );
    is_deeply \@content, [ "Line1", "Line2", $line3 ], "lines+chomp+crlf+utf8";

    $file->remove;
    ok not -e $file;
}

{
    my $file = path( $tmpdir, 'spew' );
    $file->remove() if $file->exists;
    $file->spew( { binmode => ':raw' }, "Line1\r\n" );
    $file->append( { binmode => ':raw' }, "Line2" );

    my $content = $file->slurp( { binmode => ':raw' } );

    is( $content, "Line1\r\nLine2" );
}

{
    # Make sure we can make an absolute/relative roundtrip
    my $cwd = path();
    is $cwd, $cwd->absolute->relative,
      "from $cwd to " . $cwd->absolute . " to " . $cwd->absolute->relative;
}

{
    my $file = $tmpdir->child("foo.txt");
    $file->spew("Hello World\n");
    my $copy = $tmpdir->child("bar.txt");
    $file->copy($copy);
    is( $copy->slurp, "Hello World\n", "file copied" );
    chmod 0400, $copy; # read only
    SKIP: {
      skip "No exception if run as root", 1 if $> == 0;
      ok( exception { $file->copy($copy) }, "copy throws error if permission denied" );
    }
}

SKIP: {
    my $newtmp = Path::Tiny->tempdir;
    my $file   = $newtmp->child("foo.txt");
    my $link   = $newtmp->child("bar.txt");
    $file->spew("Hello World\n");
    eval { symlink $file => $link };
    skip "symlink unavailable", 1 if $@;
    ok( $link->lstat->size, "lstat" );
}

# We don't have subsume so comment these out.  Keep in case we
# implement it later

##{
##  my $t = path( 't');
##  my $foo_bar = $t->child('foo','bar');
##  $foo_bar->remove; # Make sure it doesn't exist
##
##  ok  $t->subsumes($foo_bar), "t subsumes t/foo/bar";
##  ok !$t->contains($foo_bar), "t doesn't contain t/foo/bar";
##
##  $foo_bar->mkpath;
##  ok  $t->subsumes($foo_bar), "t still subsumes t/foo/bar";
##  ok  $t->contains($foo_bar), "t now contains t/foo/bar";
##
##  $t->child('foo')->remove;
##}

done_testing;
