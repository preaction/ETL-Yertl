
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
        my $source = $self->{source} = delete $args{source};
        weaken $self;
        $source->configure(
            on_doc => sub {
                my ( $source, $doc, $eof ) = @_;
                local $_ = $doc;
                my @docs = $self->invoke_event( transform_doc => $doc );
                # ; say "Writing docs from return: " . join ", ", @docs;
                # ; use Data::Dumper;
                # ; say STDERR Dumper( \@docs );
                $self->write( $_ ) for grep { $_ } @docs;
                return;
            },
            # XXX This probably needs to be done better:
            # * Users can't add their own handler to this event at all,
            #   making it more difficult to add Yertl streams to larger
            #   programs
            # * This requires on_read_eof to be called after all
            #   transforms are complete, which prevents cooperative
            #   multitasking by using `$self->loop->later` to defer
            #   execution of the transform_doc method/callback
            on_read_eof => sub {
                if ( my $dest = $self->{destination} ) {
                    if ( $dest->{write_handle} != \*STDOUT ) {
                        # Gracefully close the destination and then let
                        # anyone using us as a source know we're finished
                        $dest->configure( on_closed => sub {
                            $self->maybe_invoke_event( 'on_read_eof' );
                        } );
                        $dest->close_when_empty;
                        return;
                    }
                }
                # We emit our own on_read_eof event so downstream things
                # can clean up
                $self->maybe_invoke_event( 'on_read_eof' );
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

    for my $event ( qw( transform_doc on_doc on_read_eof ) ) {
        $self->{ $event } = delete $args{ $event } if exists $args{ $event };
    }
    croak "Expected either a transform_doc callback or to be able to ->transform_doc"
        unless $self->can_event( 'transform_doc' );
    $self->{on_doc} ||= sub { }; # Default on_doc does nothing
    $self->{on_read_eof} ||= sub {
        main::loop()->stop;
    }; # Default on_read_eof exits the loop

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
            say STDERR "# Hey";
            # Return instead of write
            ; say "Returning a doc";
            return $_;
        },
    ) >> file( '>', 'output.yaml' )
    ;

# loop()->run
loop->run;

