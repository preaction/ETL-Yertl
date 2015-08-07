
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Format::yaml;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $script = "$FindBin::Bin/../../bin/ygrok";
require $script;
$0 = $script; # So pod2usage finds the right file

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ygrok->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a pattern}, 'contains error message';
    };
};

sub test_ygrok {
    my ( $file, $pattern, $expect, $args ) = @_;

    $args ||= [];

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ygrok->main( @$args, $pattern, $file ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        my @docs = $yaml_fmt->read;
        cmp_deeply \@docs, $expect or diag explain \@docs;;
    };

    subtest 'stdin' => sub {
        local *STDIN = $file->openr;
        my ( $stdout, $stderr, $exit ) = capture { ygrok->main( @$args, $pattern ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        my @docs = $yaml_fmt->read;
        cmp_deeply \@docs, $expect or diag explain \@docs;
    };
}

subtest 'parse lines' => sub {
    my $file = $SHARE_DIR->child( lines => 'irc.txt' );
    my $pattern = '%{DATE.ISO8601:timestamp} %{WORD:user}@%{NET.IPV4:ip}> %{DATA:text}';
    my @expect = (
        {
            timestamp => '2014-01-01T00:00:00Z',
            user => 'preaction',
            ip => '127.0.0.1',
            text => 'Hello, world!',
        },
        {
            timestamp => '2014-01-01T00:15:24Z',
            user => 'jberger',
            ip => '127.0.1.1',
            text => 'Hello, preaction!',
        },
        {
            timestamp => '2014-01-01T01:14:51Z',
            user => 'preaction',
            ip => '127.0.0.1',
            text => 'Hello, jberger!',
        },
    );

    test_ygrok( $file, $pattern, \@expect );

    subtest 'loose parsing' => sub {
        my $file = $SHARE_DIR->child( lines => 'irc.txt' );
        my $pattern = '> %{DATA:text}$';
        my @expect = (
            {
                text => 'Hello, world!',
            },
            {
                text => 'Hello, preaction!',
            },
            {
                text => 'Hello, jberger!',
            },
        );

        test_ygrok( $file, $pattern, \@expect, [ '-l' ] );
    };

};

subtest 'logs' => sub {

    subtest 'http common log format' => sub {
        my $file = $SHARE_DIR->child( lines => 'http_common_log.txt' );
        my $pattern = join " ", '%{NET.HOSTNAME:remote_addr}', '%{OS.USER:ident}', '%{OS.USER:user}',
                                '\[%{DATE.HTTP:timestamp}]',
                                '"%{WORD:method} %{URL.PATH:path} [^/]+/%{VERSION:http_version}"',
                                '%{INT:status}', '(?<content_length>\d+|-)',
                                ;

        my @expect = (
            {
                remote_addr => 'www.preaction.me',
                ident => 'doug',
                user => 'preaction',
                timestamp => '10/Oct/2000:13:55:36 -0700',
                method => 'GET',
                path => '/',
                http_version => '1.0',
                status => '200',
                content_length => 2326,
            },

            {
                remote_addr => '127.0.1.1',
                ident => '-',
                user => 'jberger',
                timestamp => '21/Nov/2001:18:02:42 -0800',
                method => 'GET',
                path => '/foo/bar/baz?fizz=no&buzz=yes',
                http_version => '1.1',
                status => '200',
                content_length => 236,
            },

            {
                remote_addr => '127.0.0.1',
                ident => '-',
                user => 'preaction',
                timestamp => '01/Jan/2002:13:55:36 +0500',
                method => 'POST',
                path => '/blog/edit',
                http_version => '1.1',
                status => '200',
                content_length => 326,
            },

            {
                remote_addr => '127.1.0.1',
                ident => '-',
                user => 'murphy',
                timestamp => '24/Jun/2015:06:12:36 -0000',
                method => 'GET',
                path => '/NOT_FOUND',
                http_version => '1.0',
                status => '404',
                content_length => 124,
            },

            {
                remote_addr => 'bonzi.example.com',
                ident => '-',
                user => 'morty',
                timestamp => '04/Mar/2015:12:24:38 -0600',
                method => 'read',
                path => '/ping',
                http_version => '1.16.2',
                status => '200',
                content_length => '-',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{LOG.HTTP_COMMON}", \@expect )
    };

    subtest 'http combined log format' => sub {
        my $file = $SHARE_DIR->child( lines => 'http_combined_log.txt' );
        my $pattern = join " ", '%{LOG.HTTP_COMMON}',
                                '"%{URL:referer}"', '"%{DATA:user_agent}"',
                                ;

        my @expect = (
            {
                remote_addr => 'www.preaction.me',
                ident => 'doug',
                user => 'preaction',
                timestamp => '10/Oct/2000:13:55:36 -0700',
                method => 'GET',
                path => '/',
                http_version => '1.0',
                status => '200',
                content_length => 2326,
                referer => 'http://example.com/referer',
                user_agent => 'Mozilla/5.0 And A Lot of Other Stuff',
            },

            {
                remote_addr => '127.0.1.1',
                ident => '-',
                user => 'jberger',
                timestamp => '21/Nov/2001:18:02:42 -0800',
                method => 'GET',
                path => '/foo/bar/baz?fizz=no&buzz=yes',
                http_version => '1.1',
                status => '200',
                content_length => 236,
                referer => '-',
                user_agent => 'Mojolicious/5.1',
            },

            {
                remote_addr => '127.0.0.1',
                ident => '-',
                user => 'preaction',
                timestamp => '01/Jan/2002:13:55:36 +0500',
                method => 'POST',
                path => '/blog/edit',
                http_version => '1.1',
                status => '200',
                content_length => 326,
                referer => '/blog',
                user_agent => 'Mozilla/4.2 (Compatible; MSIE 5.0)',
            },

            {
                remote_addr => '127.1.0.1',
                ident => '-',
                user => 'murphy',
                timestamp => '24/Jun/2015:06:12:36 -0000',
                method => 'GET',
                path => '/NOT_FOUND',
                http_version => '1.0',
                status => '404',
                content_length => 124,
                referer => '-',
                user_agent => 'GoogleBot/1.0',
            },

            {
                remote_addr => 'bonzi.example.com',
                ident => '-',
                user => 'morty',
                timestamp => '04/Mar/2015:12:24:38 -0600',
                method => 'read',
                path => '/ping',
                http_version => '1.16.2',
                status => '200',
                content_length => '-',
                referer => '-',
                user_agent => 'Github/1.2 Something/2.4 Other/0.0',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{LOG.HTTP_COMBINED}", \@expect )
    };

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

};

subtest 'POSIX command parsing' => sub {

    subtest 'ls -l' => sub {
        my $file = $SHARE_DIR->child( lines => 'ls-l.txt' );
        my $pattern = join( " +",
            '(?<mode>[bcdlsp-][rwxSsTt-]{9})',
            '%{INT:links}',
            '%{OS.USER:owner}',
            '%{OS.USER:group}',
            '%{INT:bytes}',
            '(?<modified>%{DATE.MONTH} +\d+ +\d+(?::\d+)?)',
            '%{DATA:name}',
        );

        my @expect = (
            {
                mode => 'drwxr-xr-x',
                links => 15,
                owner => 'doug',
                group => 'staff',
                bytes => 510,
                modified => 'Jan 28 19:37',
                name => 'ETL-Yertl-0.021',
            },
            {
                mode => '-rw-r--r--',
                links => 1,
                owner => 'doug',
                group => 'staff',
                bytes => 43666,
                modified => 'Jan 28 19:37',
                name => 'ETL-Yertl-0.021.tar.gz',
            },
            {
                mode => 'drwxr-xr-x',
                links => 9,
                owner => 'doug',
                group => 'staff',
                bytes => 306,
                modified => 'Feb  1 19:44',
                name => 'bin',
            },
            {
                mode => '-rw-r--r--',
                links => 1,
                owner => 'doug',
                group => 'staff',
                bytes => 3654,
                modified => 'Feb  1  2012',
                name => 'dist.ini',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.LS}", \@expect )
    };

    subtest 'ps' => sub {
        my $pattern = join( " +",
            ' *%{INT:pid}',
            '(?<tty>[\w?/]+)',
            '(?<status>(?:[\w+]+))?',
            '(?<time>\d+:\d+(?:[:.]\d+)?)',
            '%{DATA:command}',
        );

        subtest 'Mac OSX' => sub {
            my $file = $SHARE_DIR->child( lines => macosx => 'ps.txt' ),
            my @expect = (
                {
                    pid => 20045,
                    tty => 'ttys000',
                    time => '0:00.01',
                    command => '-ksh (ksh)',
                },
                {
                    pid => 2643,
                    tty => 'ttys001',
                    time => '0:00.01',
                    command => 'ps',
                },
            );

            test_ygrok( $file, $pattern, \@expect );
            test_ygrok( $file, "%{POSIX.PS}", \@expect )
        };

        subtest 'OpenBSD' => sub {
            my $file = $SHARE_DIR->child( lines => openbsd => 'ps.txt' ),
            my @expect = (
                {
                    pid => 20045,
                    tty => 'p0',
                    status => 'Ss',
                    time => '0:00.01',
                    command => '-ksh (ksh)',
                },
                {
                    pid => 2643,
                    tty => 'p0',
                    status => 'R+',
                    time => '0:00.01',
                    command => 'ps',
                },
            );

            test_ygrok( $file, $pattern, \@expect );
            test_ygrok( $file, "%{POSIX.PS}", \@expect )
        };

        subtest 'RHEL5' => sub {
            my $file = $SHARE_DIR->child( lines => rhel5 => 'ps.txt' ),
            my @expect = (
                {
                    pid => 3075,
                    tty => 'pts/0',
                    time => '00:00:00',
                    command => 'zsh',
                },
                {
                    pid => 5076,
                    tty => 'pts/0',
                    time => '00:00:00',
                    command => 'ps',
                },
            );

            test_ygrok( $file, $pattern, \@expect );
            test_ygrok( $file, "%{POSIX.PS}", \@expect )
        };

    };

    subtest 'ps -x' => sub {
        my $pattern = join( " +",
            ' *%{INT:pid}',
            '(?<tty>[\w?/]+)',
            '(?<status>(?:[\w+]+))',
            '(?<time>\d+:\d+(?:[:.]\d+)?)',
            '%{DATA:command}',
        );

        subtest 'Mac OSX' => sub {
            my $file = $SHARE_DIR->child( lines => macosx => 'ps-x.txt' ),
            my @expect = (
                {
                    pid => 253,
                    tty => '??',
                    status => 'Ss',
                    time => '0:00.07',
                    command => '/System/Library/Frameworks/QTKit.framework/Versions/A/XPCServices/com.apple.qtkitserver.xpc/Contents/MacOS/com.apple.qtkitserver',
                },
                {
                    pid => 298,
                    tty => '??',
                    status => 'S',
                    time => '0:21.06',
                    command => '/usr/libexec/UserEventAgent (Aqua)',
                },
                {
                    pid => 300,
                    tty => '??',
                    status => 'S',
                    time => '0:39.88',
                    command => '/usr/sbin/distnoted agent',
                },
            );

            test_ygrok( $file, $pattern, \@expect );
            test_ygrok( $file, "%{POSIX.PSX}", \@expect )
        };

        subtest 'OpenBSD' => sub {
            my $file = $SHARE_DIR->child( lines => openbsd => 'ps-x.txt' ),
            my @expect = (
                {
                    pid => 3713,
                    tty => '??',
                    status => 'S',
                    time => '0:00.03',
                    command => 'sshd: doug@ttyp0 (sshd)',
                },
                {
                    pid => 20045,
                    tty => 'p0',
                    status => 'Ss',
                    time => '0:00.02',
                    command => '-ksh (ksh)',
                },
                {
                    pid => 4243,
                    tty => 'p0',
                    status => 'R+',
                    time => '0:00.00',
                    command => 'ps -x',
                },
            );

            test_ygrok( $file, $pattern, \@expect );
            test_ygrok( $file, "%{POSIX.PSX}", \@expect )
        };

        subtest 'RHEL5' => sub {
            my $file = $SHARE_DIR->child( lines => rhel5 => 'ps-x.txt' ),
            my @expect = (
                {
                    pid => 3075,
                    tty => 'pts/0',
                    status => 'Ss',
                    time => '0:00',
                    command => '/usr/local/bin/zsh',
                },
                {
                    pid => 5345,
                    tty => '?',
                    status => 'Sl',
                    time => '219:15',
                    command => 'starman master',
                },
            );

            test_ygrok( $file, $pattern, \@expect );
            test_ygrok( $file, "%{POSIX.PSX}", \@expect )
        };
    };

    subtest 'ps -u' => sub {
        my $pattern = join( " +",
            '%{OS.USER:user}',
            '%{INT:pid}',
            '%{NUM:cpu}',
            '%{NUM:mem}',
            '%{INT:vsz}',
            '%{INT:rss}',
            '(?<tty>[\w?/]+)',
            '(?<status>(?:[\w+]+))?',
            '(?<started>[\w:]+)',
            '(?<time>\d+:\d+(?:[:.]\d+)?)',
            '%{DATA:command}',
        );

        subtest 'Mac OSX' => sub {
            my $file = $SHARE_DIR->child( lines => macosx => 'ps-u.txt' ),
            my @expect = (
                {
                    user => 'doug',
                    pid => 617,
                    cpu => '0.0',
                    mem => 0.1,
                    vsz => 2499620,
                    rss => 5432,
                    tty => 's001',
                    status => 'Ss',
                    started => 'Sat12PM',
                    time => '0:01.92',
                    command => '-zsh',
                },
                {
                    user => 'doug',
                    pid => 7201,
                    cpu => '0.0',
                    mem => 0.1,
                    vsz => 2500644,
                    rss => 7404,
                    tty => 's004',
                    status => 'Ss',
                    started => 'Sat07PM',
                    time => '0:05.37',
                    command => '-zsh',
                },
            );

            test_ygrok( $file, $pattern, \@expect );
            test_ygrok( $file, "%{POSIX.PSU}", \@expect )
        };

        subtest 'OpenBSD' => sub {
            my $file = $SHARE_DIR->child( lines => openbsd => 'ps-u.txt' ),
            my @expect = (
                {
                    user => 'doug',
                    pid => 20045,
                    cpu => '0.0',
                    mem => '0.0',
                    vsz => 680,
                    rss => 492,
                    tty => 'p0',
                    status => 'Rs',
                    started => '2:28PM',
                    time => '0:00.01',
                    command => '-ksh (ksh)',
                },
                {
                    user => 'doug',
                    pid => 27069,
                    cpu => '0.0',
                    mem => '0.0',
                    vsz => 344,
                    rss => 248,
                    tty => 'p0',
                    status => 'R+',
                    started => '2:28PM',
                    time => '0:00.00',
                    command => 'ps -u',
                },
            );

            test_ygrok( $file, $pattern, \@expect );
            test_ygrok( $file, "%{POSIX.PSU}", \@expect )
        };

        subtest 'RHEL5' => sub {
            my $file = $SHARE_DIR->child( lines => rhel5 => 'ps-u.txt' ),
            my @expect = (
                {
                    user => 'username', pid => 3075,        cpu => '0.0',
                    mem => '0.0',       vsz => 89124,       rss => 3336,
                    tty => 'pts/0',     status => 'Ss',     started => '18:29',
                    time => '0:00',     command => '/usr2/local/bin/zsh',
                },
                {
                    user => 'username', pid => 5248,        cpu => '0.0',
                    mem => '0.0',       vsz => 69824,       rss => 1084,
                    tty => 'pts/0',     status => 'R+',     started => '18:33',
                    time => '0:00',     command => 'ps u',
                },
                {
                    user => 'username', pid => 5249,        cpu => '0.0',
                    mem => '0.0',       vsz => 58940,       rss => 576,
                    tty => 'pts/0',     status => 'S+',     started => '18:33',
                    time => '0:00',     command => 'head',
                },
                {
                    user => 'username', pid => 20645,       cpu => '0.0',
                    mem => '0.0',       vsz => 64892,       rss => 1436,
                    tty => 'pts/1',     status => 'Ss+',    started => '2014',
                    time => '0:00',     command => '/bin/ksh',
                },
            );

            test_ygrok( $file, $pattern, \@expect );
            test_ygrok( $file, "%{POSIX.PSU}", \@expect )
        };

    };
};

subtest 'manage patterns' => sub {

    my $test_conf = sub {
        my ( $home, $args, $expect ) = @_;

        my ( $stdout, $stderr, $exit ) = capture { ygrok->main( @$args ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;

        my $yaml_config = ETL::Yertl::Format::yaml->new(
            input => $home->child( '.yertl', 'ygrok.yml' )->openr,
        );
        my ( $config ) = $yaml_config->read;
        cmp_deeply $config, $expect, 'config is correct'
            or diag explain $config;
    };

    subtest 'plain pattern' => sub {
        my $home = tempdir;
        local $ENV{HOME} = "$home";

        subtest 'add pattern' => $test_conf,
            $home,
            [ '--pattern', 'TEST', 'test::\S+' ],
            { TEST => 'test::\S+' }
            ;

        subtest 'use pattern' => sub {
            my $file = $SHARE_DIR->child( lines => 'custom_plain.txt' );
            my $pattern = '%{INT:line} %{TEST:string}';
            my @expect = (
                {
                    line => 1,
                    string => 'test::this_is_a_test',
                },
                {
                    line => 2,
                    string => 'test::another_test',
                },
            );
            test_ygrok( $file, $pattern, \@expect );
        };

        subtest 'edit pattern' => $test_conf,
            $home,
            [ '--pattern', 'TEST', '.+' ],
            { TEST => '.+' }
            ;

        subtest 'use edited pattern' => sub {
            my $file = $SHARE_DIR->child( lines => 'custom_plain_edit.txt' );
            my $pattern = '%{INT:line} %{TEST:string}';
            my @expect = (
                {
                    line => 1,
                    string => 'test this_is_a_test',
                },
                {
                    line => 2,
                    string => 'test another_test',
                },
            );
            test_ygrok( $file, $pattern, \@expect );
        };
    };

    subtest 'pattern category' => sub {
        my $home = tempdir;
        local $ENV{HOME} = "$home";

        subtest 'add pattern' => $test_conf,
            $home,
            [ '--pattern', 'TEST.FOO', '[1-9a-z]+' ],
            { TEST => { FOO => '[1-9a-z]+' } }
            ;

        subtest 'use pattern' => sub {
            my $file = $SHARE_DIR->child( lines => 'custom_category.txt' );
            my $pattern = '%{INT:line} %{TEST.FOO:string}';
            my @expect = (
                {
                    line => 1,
                    string => 'fizz1buzz',
                },
                {
                    line => 2,
                    string => 'fizz5fizz15',
                },
            );
            test_ygrok( $file, $pattern, \@expect );
        };

        subtest 'edit pattern' => $test_conf,
            $home,
            [ '--pattern', 'TEST.FOO', '[1-9a-z ]+' ],
            { TEST => { FOO => '[1-9a-z ]+' } }
            ;

        subtest 'use edited pattern' => sub {
            my $file = $SHARE_DIR->child( lines => 'custom_category_edit.txt' );
            my $pattern = '%{INT:line} %{TEST.FOO:string}';
            my @expect = (
                {
                    line => 1,
                    string => 'fizz 1 buzz',
                },
                {
                    line => 2,
                    string => 'fizz 5 fizz 15',
                },
            );
            test_ygrok( $file, $pattern, \@expect );
        };
    };

    subtest 'override built-in patterns' => sub {
        my $home = tempdir;
        local $ENV{HOME} = "$home";

        subtest 'add pattern' => $test_conf,
            $home,
            [ '--pattern', 'NET.HOSTNAME', '~[a-z][a-z0-9.]+' ],
            { NET => { HOSTNAME => '~[a-z][a-z0-9.]+' } }
            ;

        subtest 'use pattern' => sub {
            my $file = $SHARE_DIR->child( lines => 'custom_override.txt' );
            my $pattern = '%{INT:line} %{NET.HOSTNAME:host}';
            my @expect = (
                {
                    line => 1,
                    host => '~www.example.com',
                },
                {
                    line => 2,
                    host => '~www4.example.net',
                },
            );
            test_ygrok( $file, $pattern, \@expect );
        };

        subtest 'edit pattern' => $test_conf,
            $home,
            [ '--pattern', 'NET.HOSTNAME', '!![a-z][a-z0-9.]+' ],
            { NET => { HOSTNAME => '!![a-z][a-z0-9.]+' } }
            ;

        subtest 'use pattern' => sub {
            my $file = $SHARE_DIR->child( lines => 'custom_override_edit.txt' );
            my $pattern = '%{INT:line} %{NET.HOSTNAME:host}';
            my @expect = (
                {
                    line => 1,
                    host => '!!www.example.com',
                },
                {
                    line => 2,
                    host => '!!www4.example.net',
                },
            );
            test_ygrok( $file, $pattern, \@expect );
        };
    };

    subtest 'list patterns' => sub {
        my $home = tempdir;
        local $ENV{HOME} = "$home";

        subtest 'add pattern' => $test_conf,
            $home,
            [ '--pattern', 'NET.HOSTNAME', '~[a-z][a-z0-9.]+' ],
            { NET => { HOSTNAME => '~[a-z][a-z0-9.]+' } }
            ;

        subtest 'list a single pattern' => sub {
            my ( $stdout, $stderr, $exit ) = capture { ygrok->main( '--pattern', 'WORD' ) };
            is $exit, 0, 'exit 0';
            ok !$stderr, 'nothing on stderr' or diag $stderr;
            is $stdout, '\b\w+\b' . "\n", 'pattern is shown on stdout';

            ( $stdout, $stderr, $exit ) = capture { ygrok->main( '--pattern', 'NET.HOSTNAME' ) };
            is $exit, 0, 'exit 0';
            ok !$stderr, 'nothing on stderr' or diag $stderr;
            is $stdout, '~[a-z][a-z0-9.]+' . "\n", 'pattern is shown on stdout';
        };

        subtest 'list a category' => sub {
            my ( $stdout, $stderr, $exit ) = capture { ygrok->main( '--pattern', 'NET' ) };
            is $exit, 0, 'exit 0';
            ok !$stderr, 'nothing on stderr' or diag $stderr;
            open my $fh, '<', \$stdout;
            my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
            my @docs = $yaml_fmt->read;
            cmp_deeply \@docs,
                [
                    {
                        %{ $ETL::Yertl::Command::ygrok::PATTERNS{ NET } },
                        HOSTNAME => '~[a-z][a-z0-9.]+',
                    }
                ]
                or diag explain \@docs;
        };

        subtest 'list all patterns' => sub {
            my ( $stdout, $stderr, $exit ) = capture { ygrok->main( '--pattern' ) };
            is $exit, 0, 'exit 0';
            ok !$stderr, 'nothing on stderr' or diag $stderr;
            open my $fh, '<', \$stdout;
            my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
            my @docs = $yaml_fmt->read;
            cmp_deeply \@docs,
                [
                    {
                        %ETL::Yertl::Command::ygrok::PATTERNS,
                        NET => {
                            %{ $ETL::Yertl::Command::ygrok::PATTERNS{ NET } },
                            HOSTNAME => '~[a-z][a-z0-9.]+',
                        },
                    }
                ]
                or diag explain \@docs;;
        };

    };
};

done_testing;
