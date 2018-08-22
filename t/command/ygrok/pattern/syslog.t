
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Command::ygrok;
my $SHARE_DIR = path( __DIR__, '..', '..', '..', 'share' );

sub test_ygrok {
    my ( $file, $pattern, $expect, $args ) = @_;

    $args ||= [];

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture {
            ETL::Yertl::Command::ygrok->main( @$args, $pattern, $file );
        };
        ok !$exit, 'nothing returned';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        my @docs = docs_from_string( $stdout );
        cmp_deeply \@docs, $expect or diag explain \@docs;;
    };

    subtest 'stdin' => sub {
        local *STDIN = $file->openr;
        my ( $stdout, $stderr, $exit ) = capture {
            ETL::Yertl::Command::ygrok->main( @$args, $pattern );
        };
        ok !$exit, 'nothing returned';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        my @docs = docs_from_string( $stdout );
        cmp_deeply \@docs, $expect or diag explain \@docs;
    };
}

subtest 'syslog' => sub {
    my $file = $SHARE_DIR->child( lines => 'syslog.txt' );
    my $pattern = join( "",
        '(?<timestamp>%{DATE.MONTH} +\d{1,2} \d{1,2}:\d{1,2}:\d{1,2}) ',
        '(?:[<]%{INT:facility}.%{INT:priority}[>] )?',
        '%{NET.HOSTNAME:host} ',
        '%{OS.PROCNAME:program}(?:\[%{INT:pid}\])?: ',
        '%{DATA:text}',
    );

    my @expect = (
        {
            timestamp => 'Oct 17 08:59:00',
            host => 'suod',
            program => 'newsyslog',
            pid => '6215',
            text => 'logfile turned over',
        },
        {
            timestamp => 'Oct 17 08:59:04',
            host => 'cdr.cs.colorado.edu',
            program => 'amd',
            pid => '29648',
            text => 'noconn option exists, and was turned on! (May cause NFS hangs on some systems...)',
        },
        {
            timestamp => 'Oct 17 08:59:09',
            host => 'freestuff.cs.colorado.edu',
            program => 'ftpd',
            pid => '4502',
            text => 'FTP ACCESS REFUSED (anonymous password not rfc822) from sdn-ar-001nmalbuP302.dialsprint.net [168.191.180.168]',
        },
        {
            timestamp => 'Oct 17 08:59:24',
            host => 'peradam.cs.colorado.edu',
            program => 'sendmail',
            pid => '21601',
            text => q{e9HExOW21601: SYSERR(root): Can't create transcript file ./xfe9HExOW21601: Permission denied},
        },
    );

    test_ygrok( $file, $pattern, \@expect );
    test_ygrok( $file, "%{LOG.SYSLOG}", \@expect )
};

done_testing;
