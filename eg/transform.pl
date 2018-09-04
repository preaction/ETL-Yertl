
package Local::Dump;
BEGIN { $INC{ 'Local/Dump.pm' } = __FILE__ };
use ETL::Yertl;
use Data::Dumper;
use base 'ETL::Yertl::Transform';

sub transform_doc {
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 0;
    say STDERR "# DUMPER: " . Dumper( $_ );
    return $_;
}

package Local::AddHello;
BEGIN { $INC{ 'Local/AddHello.pm' } = __FILE__ };
use ETL::Yertl;
use base 'ETL::Yertl::Transform';

sub transform_doc {
    my ( $self, $doc ) = @_;
    if ( ref $doc eq 'HASH' ) {
        $doc->{__HELLO__} = "World";
    }
    $self->write( $doc );
}

package main;
use ETL::Yertl;
use Local::Dump;
use Local::AddHello;

my $xform
    = stdin( format => 'json' )
    | transform( "Local::Dump" )
    | transform( "Local::AddHello" ) >> stdout()
    | transform(
        sub {
            say STDERR "# Hey";
            # Return instead of write
            ; say "Returning a doc";
            return $_;
        },
    ) >> file( '>', 'output.yaml' )
    ;

# loop()->run
$xform->run;

