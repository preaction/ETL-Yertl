package ETL::Yertl::Format::default;
our $VERSION = '0.029';
# ABSTRACT: The default format for intra-Yertl communication

=head1 SYNOPSIS

    my $out_formatter = ETL::Yertl::Format::default->new;
    print $formatter->write( $document );

    my $in_formatter = ETL::Yertl::Format::default->new(
        input => \*STDIN,
    );
    my $document = $formatter->read;

=head1 DESCRIPTION

This is the default format for Yertl programs talking to each other. By
default, this is C<YAML>, but it can be set to C<JSON> by setting the
C<YERTL_FORMAT> environment variable to C<"json">.

Setting the default format to something besides YAML can help
interoperate with other programs like
L<jq|https://stedolan.github.io/jq/> or L<recs|App::RecordStream>.

=cut

use ETL::Yertl;
use Module::Runtime qw( use_module );

=method new

    my $formatter = ETL::Yertl::Format::default->new( %args );

Get an instance of the default formatter. The arguments will be passed
to the correct formatter module.

=cut

sub new {
    my ( $class, @args ) = @_;
    my $format = $ENV{YERTL_FORMAT} || 'yaml';
    my $format_class = "ETL::Yertl::Format::$format";
    return use_module( $format_class )->new( @args );
}

1;

=head1 SEE ALSO

=over 4

=item L<ETL::Yertl::Format::yaml>

The YAML formatter

=item L<ETL::Yertl::Format::json>

The JSON formatter

=back

