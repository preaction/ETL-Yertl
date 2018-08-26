
package ETL::Yertl::Transform;
$INC{ 'ETL/Yertl/Transform.pm' } = __FILE__;
use ETL::Yertl;
use curry;
use Scalar::Util qw( weaken );
use Carp qw( croak );

use base 'IO::Async::Notifier';

sub configure {
    my ( $self, %args ) = @_;

    if ( $args{source} ) {
        # Register ourselves with the source
        # XXX What happens to our original source?
        my $source = $self->{source} = delete $args{source};
        weaken $self;
        $source->configure(
            on_doc => sub {
                my ( $source, $doc, $eof ) = @_;
                # Use `later` for cooperative multi-tasking. If our
                # transform_doc event takes a long time or if we have
                # a very long chain of transforms, we could wait a long
                # time before reading from the input buffer again.
                # This should get us better performance in reading at
                # the expense of memory. If memory use becomes
                # a problem, if we can't finish writing fast enough, we
                # might need a more intelligent solution here (a number
                # of documents in-flight based on memory size or
                # something).
                $self->loop->later( sub {
                    my @docs = $self->invoke_event( transform_doc => $doc );
                    # ; say "Writing docs from return: " . join ", ", @docs;
                    # ; use Data::Dumper;
                    # ; say STDERR Dumper( \@docs );
                    $self->write( $_ ) for grep { $_ } @docs;
                } );
                return;
            },
        );
    }
    elsif ( !$self->{source} ) {
        # If we remove this requirement, we can configure objects and
        # add sources to them later, which could enable a bunch of fun
        # things like a pipe-based stream.
        # Without a source, this thing does nothing useful anyway, so
        # it'll be pretty obvious that something is broken.
        # croak "Expected a source";
    }

    if ( $args{destination} ) {
        $self->{destination} = delete $args{destination};
    }

    for my $event ( qw( transform_doc on_doc ) ) {
        $self->{ $event } = delete $args{ $event } if exists $args{ $event };
    }
    croak "Expected either a transform_doc callback or to be able to ->transform_doc"
        unless $self->can_event( 'transform_doc' );
    $self->{on_doc} ||= sub { }; # Default on_doc does nothing

    $self->SUPER::configure( %args );
}

sub write {
    my ( $self, $doc ) = @_;
    if ( my $dest = $self->{destination} ) {
        # ; say "Writing to output $dest";
        $dest->write( $doc );
    }
    $self->invoke_event( on_doc => $doc );
}

package ETL::Yertl::Transform::Dump;
BEGIN { $INC{ 'ETL/Yertl/Transform/Dump.pm' } = __FILE__ };
use ETL::Yertl;
use Data::Dumper;
use base 'ETL::Yertl::Transform';

sub transform_doc {
    my ( $self, $doc ) = @_;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 0;
    say STDERR "# DUMPER: " . Dumper( $doc );
    $self->write( $doc );
}

package ETL::Yertl::Transform::AddHello;
BEGIN { $INC{ 'ETL/Yertl/Transform/AddHello.pm' } = __FILE__ };
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
use ETL::Yertl::FormatStream;
use ETL::Yertl::Format;
use ETL::Yertl::Transform::Dump;
use ETL::Yertl::Transform::AddHello;
use IO::Async::Loop;

my $loop = IO::Async::Loop->new;

my $input = ETL::Yertl::FormatStream->new_for_stdin(
    format => ETL::Yertl::Format->get( 'json' ),
);
$loop->add( $input );
my $output = ETL::Yertl::FormatStream->new_for_stdout(
    autoflush => 1,
    format => ETL::Yertl::Format->get_default,
);
$loop->add( $output );

my $xform = ETL::Yertl::Transform::Dump->new(
    source => $input,
);
$loop->add( $xform );

my $xform2 = ETL::Yertl::Transform::AddHello->new(
    source => $xform,
    destination => $output, # intermediate destination
);
$loop->add( $xform2 );

open my $fh, '>', 'output.yaml';
my $output2 = ETL::Yertl::FormatStream->new(
    write_handle => $fh,
);
$loop->add( $output2 );

# Simple transform as callback
my $xform3 = ETL::Yertl::Transform->new(
    source => $xform2,
    transform_doc => sub {
        my ( $self, $doc ) = @_;
        say STDERR "# Hey";
        # Return instead of write
        ; say "Returning a doc";
        return $doc;
    },
    destination => $output2,
);
$loop->add( $xform3 );

$loop->run;


