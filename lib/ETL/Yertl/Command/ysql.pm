package ETL::Yertl::Command::ysql;

use ETL::Yertl;
use ETL::Yertl::Format::yaml;
use DBI;

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
        my $query = shift;
        my $dbh = DBI->connect( $opt{dsn} );
        my $sth = $dbh->prepare( $query );
        $sth->execute;

        while ( my $doc = $sth->fetchrow_hashref ) {
            print $out_fmt->write( $doc );
        }

        return 0;
    }

}

1;
__END__

