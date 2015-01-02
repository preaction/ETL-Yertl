package ETL::Yertl::Command::ysql;

use ETL::Yertl;
use Getopt::Long qw( GetOptionsFromArray );
use ETL::Yertl::Format::yaml;
use File::HomeDir;

BEGIN {
    eval { use DBI; };
    if ( $@ ) {
        die "Can't load ysql: Can't load DBI. Make sure the DBI module is installed.\n";
    }
}

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my $command = shift;
    die "Must give a command\n" unless $command;

    my $out_fmt = ETL::Yertl::Format::yaml->new;

    if ( $command eq 'query' ) {
        my @dbi_args = $opt{dsn} ? ( $opt{dsn} ) : dbi_args( shift );
        my $dbh = DBI->connect( @dbi_args );

        my $query = shift;
        my $sth = $dbh->prepare( $query );
        $sth->execute;

        while ( my $doc = $sth->fetchrow_hashref ) {
            print $out_fmt->write( $doc );
        }

        return 0;
    }
    elsif ( $command eq 'write' ) {
        my @dbi_args = $opt{dsn} ? ( $opt{dsn} ) : dbi_args( shift );
        my $dbh = DBI->connect( @dbi_args );

        my $query = shift;
        my @fields = $query =~ m/\$(\.[.\w]+)/g;
        $query =~ s/\$\.[\w.]+/?/g;

        my $sth = $dbh->prepare( $query );

        my $in_fmt = ETL::Yertl::Format::yaml->new( input => \*STDIN );
        for my $doc ( $in_fmt->read ) {
            $sth->execute( map { select_doc( $_, $doc ) } @fields );
        }
    }
    elsif ( $command eq 'config' ) {
        my ( $db_key, @args ) = @_;

        # Get the existing config first
        my $conf_file = path( File::HomeDir->my_home, '.yertl', 'ysql.yml' );
        my $config = {};
        if ( $conf_file->exists ) {
            my $yaml = ETL::Yertl::Format::yaml->new( input => $conf_file->openr );
            ( $config ) = $yaml->read;
        }
        else {
            $conf_file->touchpath;
        }

        my $db_conf = $config->{ $db_key } ||= {};

        # Set via options
        GetOptionsFromArray( \@args, $db_conf,
            'driver|t=s',
            'database|db=s',
            'host|h=s',
            'port|p=s',
            'user|u=s',
            'password|pass=s',
        );
        #; use Data::Dumper;
        #; say "Got from options: " . Dumper $db_conf;
        #; say "Left in \@args: " . Dumper \@args;

        # Set via DSN
        if ( @args ) {
            delete $db_conf->{ $_ } for qw( driver database host port );
            my ( undef, $driver, undef, undef, $driver_dsn ) = DBI->parse_dsn( $args[0] );
            $db_conf->{ driver } = $driver;

            # The driver_dsn part is up to the driver, but we can make some guesses
            if ( $driver_dsn !~ /[=:;@]/ ) {
                $db_conf->{ database } = $driver_dsn;
            }
            elsif ( $driver_dsn =~ /^(\w+)\@([\w.]+)(?:\:(\d+))?$/ ) {
                $db_conf->{ database } = $1;
                $db_conf->{ host } = $2;
                $db_conf->{ port } = $3;
            }
            elsif ( my @parts = split /\;/, $driver_dsn ) {
                for my $part ( @parts ) {
                    my ( $part_key, $part_value ) = split /=/, $part;
                    if ( $part_key eq 'dbname' ) {
                        $part_key = 'database';
                    }
                    $db_conf->{ $part_key } = $part_value;
                }
            }
            else {
                die "Unknown driver DSN: $driver_dsn";
            }
        }

        # Write back the config
        my $yaml = ETL::Yertl::Format::yaml->new;
        $conf_file->spew( $yaml->write( $config ) );
    }
}

sub select_doc {
    my ( $select, $doc ) = @_;
    $select =~ s/^[.]//; # select must start with .
    my @parts = split /[.]/, $select;
    for my $part ( @parts ) {
        $doc = $doc->{ $part };
    }
    return $doc;
}

sub dbi_args {
    my ( $db_name ) = @_;
    my $conf_file = path( File::HomeDir->my_home, '.yertl', 'ysql.yml' );
    if ( $conf_file->exists ) {
        my $yaml = ETL::Yertl::Format::yaml->new( input => $conf_file->openr );
        my ( $config ) = $yaml->read;
        my $db_config = $config->{ $db_name };

        my $driver_dsn =
            join ";",
            map { join "=", $_, $db_config->{ $_ } }
            grep { $db_config->{ $_ } }
            qw( database host port )
            ;

        return (
            sprintf( 'dbi:%s:%s', $db_config->{driver}, $driver_dsn ),
            $db_config->{user},
            $db_config->{password},
        );
    }
}

1;
__END__

