my $file = "/usr/share/dict/words";

my $result = timethese (
    $count,
    {
        'Path::Tiny'  => sub { my $s = path($file)->slurp },
        'Path::Class' => sub { my $s = file($file)->slurp },
        'IO::All'     => sub { my $s = io($file)->slurp },
        'File::Fu'    => sub { my $s = File::Fu->file($file)->read },
    },
    "none"
);

