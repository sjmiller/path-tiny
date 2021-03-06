my $file = $INC{'Benchmark.pm'};

my $result = timethese (
    $count,
    {
        'Path::Tiny'  => sub { my $s = path($file)->slurp },
        'Path::Class' => sub { my $s = file($file)->slurp },
        'IO::All'     => sub { my $s = io($file)->slurp },
        'File::Fu'    => sub { File::Fu->file($file)->read },
    },
    "none"
);

