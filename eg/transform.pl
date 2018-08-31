
package ETL::Yertl::Transform;
$INC{ 'ETL/Yertl/Transform.pm' } = __FILE__;
use ETL::Yertl;
use curry;
use Scalar::Util qw( weaken );
use Carp qw( croak );

use base 'IO::Async::Notifier';

# override pipe, <<, and >> to set on_read_doc and on_write_doc
# handlers appropriately
use overload
    '>>' => \&_set_output,
    '<<' => \&_set_input,
    '|' => \&_pipe,
    'fallback' => 1,
    ;

sub _set_output {
    my ( $self, $output ) = @_;
    $self->configure( destination => $output );
    return $self;
}

sub _set_input {
    my ( $self, $input ) = @_;
    $self->configure( source => $input );
    return $self;
}

sub _pipe {
    my ( $self, $other, $swap ) = @_;
    if ( $swap ) {
        ( $self, $other ) = ( $other, $self );
    }
    $other->configure( source => $self );
    return $other;
}

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

package Local::Dump;
BEGIN { $INC{ 'Local/Dump.pm' } = __FILE__ };
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
use ETL::Yertl::FormatStream;
use ETL::Yertl::Format;
use Local::Dump;
use Local::AddHello;
use Module::Runtime qw( use_module );
use Carp qw( croak );

# loop() helper create/maintain loop singleton
use IO::Async::Loop;
sub loop() {
    state $loop = IO::Async::Loop->new;
    return $loop;
}

# format attribute takes simple string for named format object
sub stream(%) {
    my ( %args ) = @_;
    if ( $args{format} && !ref $args{format} ) {
        $args{format} = ETL::Yertl::Format->get( $args{format} );
    }
    my $stream = ETL::Yertl::FormatStream->new( %args );
    loop->add( $stream );
    return $stream;
}

# stdin() helper should automatically add to loop singleton
sub stdin(;%) {
    my ( %args ) = @_;
    $args{read_handle} = \*STDIN;
    return stream( %args );
}

# stdout() helper should set autoflush and add to loop singleton
sub stdout(;%) {
    my ( %args ) = @_;
    $args{write_handle} = \*STDOUT;
    $args{autoflush} //= 1;
    return stream( %args );
}

# transform( Name => %args ) helper. add to loop
# transform( sub => %args ) helper. add to loop
sub transform($;%) {
    my ( $xform, %args ) = @_;
    my $obj;
    if ( !ref $xform ) {
        my $module = $xform;
        $obj = use_module( $module )->new( %args );
    }
    elsif ( ref $xform eq 'CODE' ) {
        $obj = ETL::Yertl::Transform->new(
            %args,
            transform_doc => $xform,
        );
    }
    loop->add( $obj );
    return $obj;
}

# file( '>', $name, %args ) helper to create FormatStream + add to loop
sub file( $$;% ) {
    my ( $mode, $name, %args ) = @_;
    # Detect whether to read_handle/write_handle via '<', '>'
    open my $fh, $mode, $name
        or croak sprintf q{Can't open file "%s": %s}, $name, $!;
    if ( $mode =~ /^</ ) {
        $args{read_handle} = $fh;
    }
    elsif ( $mode =~ /^>/ ) {
        $args{write_handle} = $fh;
    }
    else {
        croak sprintf q{Can't determine if mode "%s" is read or write}, $mode;
    }
    return stream( %args );
}

my $xform
    = stdin( format => 'json' )
    | transform( "Local::Dump" )
    | transform( "Local::AddHello" ) >> stdout
    | transform(
        sub {
            my ( $self, $doc ) = @_;
            say STDERR "# Hey";
            # Return instead of write
            ; say "Returning a doc";
            return $doc;
        },
    ) >> file( '>', 'output.yaml' )
    ;

# loop()->run
loop->run;

# XXX Need to handle cleanup correctly
# Each handle with input increments input counter
# Each EOF reached decrements counter
# Once counter reaches zero, all outputs are given an on_flush callback
# that resolves a future and closed
# When all on_flush futures are resolved, we are done
# Transforms will need an on_read_eof event to link up and probably an
# on_flush event or something that we can use when everything is done

