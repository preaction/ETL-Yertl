package App::YAML::Filter::RecDescent;
# ABSTRACT: A Parse::RecDescent-based parser for programs

use App::YAML::Filter::Base;
use boolean qw( :all );
use Parse::RecDescent;

$::RD_HINT = 1;

my $grammar = q{
    program: statement ( comb statement )(s?)
        {
            use Data::Dumper;
            yq::diag( 1, "Program: " . Dumper( \@item ) );
            $return = $item[1];
        }

    statement: conditional | expr

    conditional: 'if' expr 'then' expr ( 'else' expr )(?)
        {
            $return = $item[2] ? $item[4] : $item[5][1];
        }

    expr: function_call | hash | array | binop | filter | quote_string | word
        {
            $return = $item[1];
            use Data::Dumper;
            yq::diag( 1, "Expr: " . Dumper( \@item ) );
        }

    filter: '.' <skip:""> filter_part(s? /[.]/)
        {
            use Data::Dumper;
            yq::diag( 1, "Filter: " . Dumper( \@item ) );
            my @keys = @{$item[3]};
            $return = [ $::document ];
            for my $key ( @keys ) {
                yq::diag( 1, "Key: " . Dumper( $key ) );
                if ( $key =~ /^\[\]$/ ) {
                    $return = $return->[0];
                }
                elsif ( $key =~ /^\[(\d+)\]$/ ) {
                    $return = [ $return->[0][ $1 ] ];
                }
                elsif ( $key =~ /^\w+$/ ) {
                    $return = [ $return->[0]{ $key } ];
                }
                else {
                    die "Invalid filter key '$key'";
                }
            }
        }

    filter_part: word | '[' number(?) ']'
        {
            if ( $item[1] eq '[' ) {
                $return = join "", $item[1], @{$item[2]}, $item[3];
            }
            else {
                $return = $item[1];
            }
        }

    binop: (filter|word|quote_string) op (filter|word|quote_string)
        {
            use Data::Dumper;
            yq::diag( 1, "Binop: " . Dumper( \@item ) );
            use boolean qw( true false );
            my ( $lhs_value, $cond, $rhs_value ) = ( $item[1], $item[2], $item[3] );
            if ( ref $lhs_value eq 'ARRAY' ) {
                $lhs_value = $lhs_value->[0];
            }
            if ( ref $rhs_value eq 'ARRAY' ) {
                $rhs_value = $rhs_value->[0];
            }
            # These operators suppress undef warnings, treating undef as just
            # another value. Undef will never be treated as '' or 0 here.
            if ( $cond eq 'eq' ) {
                $return = defined $lhs_value == defined $rhs_value
                    && $lhs_value eq $rhs_value ? true : false;
            }
            elsif ( $cond eq 'ne' ) {
                $return = defined $lhs_value != defined $rhs_value
                    || $lhs_value ne $rhs_value ? true : false;
            }
            elsif ( $cond eq '==' ) {
                $return = defined $lhs_value == defined $rhs_value
                    && $lhs_value == $rhs_value ? true : false;
            }
            elsif ( $cond eq '!=' ) {
                $return = defined $lhs_value != defined $rhs_value
                    || $lhs_value != $rhs_value ? true : false;
            }
            # These operators allow undef warnings, since equating undef to 0 or ''
            # can be a cause of problems.
            elsif ( $cond eq '>' ) {
                $return = $lhs_value > $rhs_value ? true : false;
            }
            elsif ( $cond eq '>=' ) {
                $return = $lhs_value >= $rhs_value ? true : false;
            }
            elsif ( $cond eq '<' ) {
                $return = $lhs_value < $rhs_value ? true : false;
            }
            elsif ( $cond eq '<=' ) {
                $return = $lhs_value <= $rhs_value ? true : false;
            }
            $return = [ $return ];
        }

    function_call: function_name arguments(?)
        {
            use Data::Dumper;
            yq::diag( 1, "FCall: " . Dumper( \@item ) );
            my $func = $item[1];
            my $args = $item[2];
            if ( $func eq 'empty' ) {
                if ( @$args ) {
                    warn "empty does not take arguments\n";
                }
                $return = undef;
            }
            elsif ( $func eq 'select' || $func eq 'grep' ) {
                if ( !@$args ) {
                    warn "'$func' takes an expression argument";
                    $return = undef;
                }
                else {
                    $return = $args->[0] ? $::document : undef;
                }
            }
            elsif ( $func eq 'group_by' ) {
                push @{ $::scope->{ group_by }{ $args->[0] } }, $::document;
                $return = undef;
            }
            elsif ( $func eq 'keys' ) {
                my $value = $args->[0] || $::document;
                if ( ref $value eq 'HASH' ) {
                    $return = [ keys %$value ];
                }
                elsif ( ref $value eq 'ARRAY' ) {
                    $return = [ 0..$#{ $value } ];
                }
                else {
                    warn "keys() requires a hash or array";
                    $return = undef;
                }
            }
            elsif ( $func eq 'length' ) {
                my $value = $args->[0] || $::document;
                if ( ref $value eq 'HASH' ) {
                    $return = keys %$value;
                }
                elsif ( ref $value eq 'ARRAY' ) {
                    $return = @$value;
                }
                elsif ( !ref $value ) {
                    $return = length $value;
                }
                else {
                    warn "length() requires a hash, array, string, or number";
                    $return = undef;
                }
            }
        }

    hash: '{' pair(s /,/) '}'
        {
            use Data::Dumper;
            yq::diag( 1, "Hash: " . Dumper \@item );
            $return = {};
            for my $i ( @{$item[2]} ) {
                $return->{ $i->[0] } = $i->[1];
            }
        }

    array: '[' expr(s /,/) ']'
        {
            use Data::Dumper;
            yq::diag( 1, "Array: " . Dumper( \@item ) );
            $return = $item[1];
        }

    arguments: '(' expr(s /,/) ')'
        {
            $return = $item[2];
            use Data::Dumper;
            yq::diag( 1, "Args: " . Dumper( \@item ) );
        }

    pair: key ':' expr
        { $return = [ @item[1,3] ] }

    key: filter | quote_string | word

    quote_string: quote non_quote quote
        { $return = join "", @item[1..$#item] }

    number: /\d+(?:[.]\d+)?(?:e\d+)?/

    word: /\w+/

    quote: /(?<!\\\\)['"]/

    non_quote: /(?:[^'"]|(?<=\\\\)['"])+/

    function_name: "empty" | "select" | "grep" | "group_by" | "keys" | "length"

    op: "eq" | "ne" | "==" | "!=" | ">" | ">=" | "<" | "<="

    comb: ',' | '|'
};

my $parser = Parse::RecDescent->new( $grammar );

sub filter {
    my ( $class, $filter, $doc, $scope ) = @_;
    ; $yq::VERBOSE = 1;
    $::document = $doc;
    $::scope = $scope;
    my $output = $parser->program( $filter );
    ; use Data::Dumper;
    ; print "OUTPUT: " . Dumper $output;
    if ( wantarray ) {
        return @$output;
    }
    else {
        return $output->[-1];
    }
}

1;
