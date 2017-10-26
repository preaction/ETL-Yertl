package ETL::Yertl::Command::yq::Regex;
our $VERSION = '0.037';
# ABSTRACT: A regex-based parser for programs

use ETL::Yertl;
use boolean qw( :all );
use Regexp::Common;
use Time::Local qw( timegm );
use ETL::Yertl::Util qw( firstidx );

sub empty() {
    bless {}, 'empty';
}

sub is_empty($) {
    return ref $_[0] eq 'empty';
}

*diag = *yertl::diag;

my $QUOTE_STRING = $RE{delimited}{-delim=>q{'"}};
my $EVAL_NUMS = qr{(?:0b$RE{num}{bin}|0$RE{num}{oct}|0x$RE{num}{hex})};

# Match a document path
our $GRAMMAR = qr{
    (?(DEFINE)
        (?<FILTER>
            (?:\$?[.](?:\w+|\[\d*\]))+ # hash/array lookup
            |
            \$?[.] # entire document
            |
            $QUOTE_STRING
            |
            $RE{num}{real}|$EVAL_NUMS
            |
            \w+ # Constant/bareword
        )
        (?<OP>eq|ne|==?|!=|>=?|<=?)
        (?<FUNC_NAME>empty|select|grep|group_by|keys|length|sort|each|parse_time)
        (?<EXPR>
            \{\s*(?&FILTER)\s*:\s*(?0)\s*(?:,(?-1))*\} # Hash constructor
            |
            \[\s*(?0)\s*(?:,(?-1))*\] # Array constructor
            |
            (?&FUNC_NAME)(?:\(\s*(?&EXPR)\s*(?:,\s*(?&EXPR)\s*)*\))? # Function with optional argument(s)
            |
            (?:(?&FILTER)|(?&FUNC_NAME)(?:\(\s*(?&EXPR)\s*\))?)\s+(?&OP)\s+(?&EXPR) # Binop with filter
            |
            (?&FILTER)
        )
    )
}x;

my $FILTER = qr{(?&FILTER)$GRAMMAR};
my $OP = qr{(?&OP)$GRAMMAR};
my $FUNC_NAME = qr{(?&FUNC_NAME)$GRAMMAR};
my $EXPR = qr{(?&EXPR)$GRAMMAR};
my $PIPE = qr{[|]};

my @DAYS = qw< sun sunday mon monday tue tuesday wed wednesday thu thursday fri friday sat saturday sun sunday>;
my $DAYS = qr{@{[ join '|', @DAYS ]}}i;
my @MONTHS = qw< jan feb mar apr may jun jul aug sep oct nov dec >;
my $MONTHS = qr{@{[ join '|', @MONTHS ]}}i;

my %PARSE_TIME = (
    iso => qr{(?<y>\d{4})-?(?<m>\d{2})-?(?<d>\d{2})(?:[ T]?(?<h>\d{2}):?(?<n>\d{2})(?::?(?<s>\d{2})))?},
    apache => qr{(?<d>\d{2})/(?<mn>$MONTHS)/(?<y>\d{4}):(?<h>\d{2}):(?<n>\d{2}):(?<s>\d{2})},
);
$PARSE_TIME{auto} = qr{$PARSE_TIME{iso}|$PARSE_TIME{apache}};

# Filter MUST NOT mutate $doc!
sub filter {
    my ( $class, $filter, $doc, $scope, $orig_doc ) = @_;
    $orig_doc ||= $doc;

    # Pipes: LEFT | RIGHT pipes the output of LEFT to the input of RIGHT
    if ( $filter =~ $PIPE ) {
        my @exprs = split /\s*$PIPE\s*/, $filter;
        my @in = ( $doc );
        for my $expr ( @exprs ) {
            my @out = ();
            for my $doc ( @in ) {
                push @out, $class->filter( $expr, $doc, $scope, $orig_doc );
            }
            @in = @out;
        }
        return @in;
    }

    # Hash constructor
    elsif ( $filter =~ /^{/ ) {
        my %out;
        my ( $inner ) = $filter =~ /^\{\s*([^\}]+?)\s*\}$/;
        for my $pair ( split /\s*,\s*/, $inner ) {
            my ( $key_filter, $value_expr ) = split /\s*:\s*/, $pair;
            my $key = $class->filter( $key_filter, $doc, $scope, $orig_doc );
            $out{ $key } = $class->filter( $value_expr, $doc, $scope, $orig_doc );
        }
        return \%out;
    }

    # Array constructor
    elsif ( $filter =~ /^\[/ ) {
        my @out;
        my ( $inner ) = $filter =~ /^\[\s*([^\]]+?)\s*\]$/;
        for my $value_expr ( split /\s*,\s*/, $inner ) {
            push @out, $class->filter( $value_expr, $doc, $scope, $orig_doc );
        }
        return \@out;
    }

    # Function calls
    elsif ( my ( $func, @args ) = $filter =~ /^((?&FUNC_NAME))(?:\(\s*((?&EXPR))\s*(?:,\s*((?&EXPR))\s*)*\))?$GRAMMAR$/ ) {
        diag( 1, "F: $func, ARGS: " . ( join( ', ', grep defined, @args ) || '' ) );
        if ( $func eq 'empty' ) {
            if ( @args ) {
                warn "empty does not take arguments\n";
            }
            return empty;
        }
        elsif ( $func eq 'select' || $func eq 'grep' ) {
            if ( !@args ) {
                warn "'$func' takes an expression argument";
                return empty;
            }
            return $class->filter( $args[0], $doc, $scope, $orig_doc ) ? $doc : empty;
        }
        elsif ( $func eq 'group_by' ) {
            my $grouping = $class->filter( $args[0], $doc, $scope, $orig_doc );
            push @{ $scope->{ group_by }{ $grouping } }, $doc;
            return;
        }
        elsif ( $func eq 'sort' ) {
            $args[0] ||= '.';
            my $value = $class->filter( $args[0], $doc, $scope, $orig_doc );
            push @{ $scope->{sort} }, [ "$value", $doc ];
            return;
        }
        elsif ( $func eq 'keys' ) {
            $args[0] ||= '.';
            my $value = $class->filter( $args[0], $doc, $scope, $orig_doc );
            if ( ref $value eq 'HASH' ) {
                return [ keys %$value ];
            }
            elsif ( ref $value eq 'ARRAY' ) {
                return [ 0..$#{ $value } ];
            }
            else {
                warn "keys() requires a hash or array";
                return empty;
            }
        }
        elsif ( $func eq 'each' ) {
            $args[0] ||= '.';
            my $value = $class->filter( $args[0], $doc, $scope, $orig_doc );
            if ( ref $value eq 'HASH' ) {
                return map +{ key => $_, value => $value->{ $_ } }, keys %$value;
            }
            elsif ( ref $value eq 'ARRAY' ) {
                return map +{ key => $_, value => $value->[ $_ ] }, 0..$#$value;
            }
            else {
                warn "each() requires a hash or array";
                return empty;
            }
        }
        elsif ( $func eq 'length' ) {
            $args[0] ||= '.';
            my $value = $class->filter( $args[0], $doc, $scope, $orig_doc );
            if ( ref $value eq 'HASH' ) {
                return scalar keys %$value;
            }
            elsif ( ref $value eq 'ARRAY' ) {
                return scalar @$value;
            }
            elsif ( !ref $value ) {
                return length $value;
            }
            else {
                warn "length() requires a hash, array, string, or number";
                return empty;
            }
        }
        elsif ( $func eq 'parse_time' ) {
            my ( $expr, $format ) = @args;
            $format ||= 'auto';
            die sprintf "Invalid format '%s' in parse_time()\n", $format
                if !$PARSE_TIME{ $format};
            my $value = $class->filter( $expr, $doc, $scope, $orig_doc );
            diag( 1, "FMT: $PARSE_TIME{ $format }, VAL: $value" );
            if ( $value =~ $PARSE_TIME{ $format } ) {
                my @tlargs = @{+}{qw< s n h d m y >};
                if ( !$+{m} && ( my $mname = $+{mn} ) ) {
                    $tlargs[4] = firstidx { /$mname/i } @MONTHS;
                }
                else {
                    $tlargs[4] -= 1;
                }
                return timegm( @tlargs );
            }
            warn sprintf "time '%s' does not match format '%s'\n", $value, $format;
            return empty;
        }
    }

    # Hash and array keys to traverse the data structure
    elsif ( $filter =~ /^((?&FILTER))$GRAMMAR$/ ) {
        # Extract quoted strings
        if ( $filter =~ /^(['"])(.+)(\1)$/ ) {
            return $2;
        }
        # Eval numbers to allow bin, hex, and oct
        elsif ( $filter =~ /^$EVAL_NUMS$/ ) {
            ## no critic ( ProhibitStringyEval )
            return eval $filter;
        }
        # Constants/barewords do not begin with .
        elsif ( $filter !~ /^[\$.]/ ) {
            # If it's not a reserved word, it's a string
            # XXX: This is a very poor decision...
            return $filter;
        }

        if ( is_empty $doc ) {
            return empty;
        }

        my @keys = split /[.]/, $filter;
        my $subdoc = $keys[0] && $keys[0] eq '$' ? $orig_doc : $doc;
        for my $key ( @keys[1..$#keys] ) {
            if ( $key =~ /^\[\]$/ ) {
                return @{ $subdoc };
            }
            elsif ( $key =~ /^\[(\d+)\]$/ ) {
                $subdoc = $subdoc->[ $1 ];
            }
            elsif ( $key =~ /^\w+$/ ) {
                $subdoc = $subdoc->{ $key };
            }
            else {
                die "Invalid filter key '$key'";
            }
        }
        return $subdoc;
    }

    # Binary operators (binops)
    elsif ( $filter =~ /^((?&FILTER)|(?&FUNC_NAME)(?:\(\s*(?&EXPR)\s*\))?)\s+((?&OP))\s+((?&EXPR))$GRAMMAR$/ ) {
        my ( $lhs_filter, $cond, $rhs_filter ) = ( $1, $2, $3 );
        if ( $cond eq '=' ) {
            # Get the referent from the left-hand side
            my @keys = split /[.]/, $lhs_filter;
            my $subdoc = $keys[0] && $keys[0] eq '$' ? \$orig_doc : \$doc;
            for my $key ( @keys[1..$#keys] ) {
                if ( $key =~ /^\[(\d+)\]$/ ) {
                    $subdoc = \( $$subdoc->[ $1 ] );
                }
                elsif ( $key =~ /^\w+$/ ) {
                    $subdoc = \( $$subdoc->{ $key } );
                }
                else {
                    die "Invalid filter key '$key'";
                }
            }

            my $rhs_value = $class->filter( $rhs_filter, $doc, $scope, $orig_doc );
            diag( 1, join " ", "BINOP:", $lhs_filter, $cond, $rhs_value // '<undef>' );
            $$subdoc = $rhs_value;
            return $doc; # Assignment does not change current document
        }
        else {
            my $lhs_value = $class->filter( $lhs_filter, $doc, $scope, $orig_doc );
            my $rhs_value = $class->filter( $rhs_filter, $doc, $scope, $orig_doc );
            diag( 1, join " ", "BINOP:", $lhs_value // '<undef>', $cond, $rhs_value // '<undef>' );
            # These operators suppress undef warnings, treating undef as just
            # another value. Undef will never be treated as '' or 0 here.
            if ( $cond eq 'eq' ) {
                return defined $lhs_value == defined $rhs_value 
                    && $lhs_value eq $rhs_value ? true : false;
            }
            elsif ( $cond eq 'ne' ) {
                return defined $lhs_value != defined $rhs_value
                    || $lhs_value ne $rhs_value ? true : false;
            }
            elsif ( $cond eq '==' ) {
                return defined $lhs_value == defined $rhs_value
                    && $lhs_value == $rhs_value ? true : false;
            }
            elsif ( $cond eq '!=' ) {
                return defined $lhs_value != defined $rhs_value
                    || $lhs_value != $rhs_value ? true : false;
            }
            # These operators allow undef warnings, since equating undef to 0 or ''
            # can be a cause of problems.
            elsif ( $cond eq '>' ) {
                return $lhs_value > $rhs_value ? true : false;
            }
            elsif ( $cond eq '>=' ) {
                return $lhs_value >= $rhs_value ? true : false;
            }
            elsif ( $cond eq '<' ) {
                return $lhs_value < $rhs_value ? true : false;
            }
            elsif ( $cond eq '<=' ) {
                return $lhs_value <= $rhs_value ? true : false;
            }
        }
    }

    # Conditional (if/then/else)
    # NOTE: If we're capturing using $EXPR, then we _must_ use named captures,
    # because $EXPR has captures in itself
    elsif ( $filter =~ /^if\s+(?<expr>$EXPR)\s+then\s+(?<true>$FILTER)(?:\s+else\s+(?<false>$FILTER))?$/ ) {
        my ( $expr, $true_filter, $false_filter ) = @+{qw( expr true false )};
        my $expr_value = $class->filter( $expr, $doc, $scope, $orig_doc );
        if ( $expr_value ) {
            return $class->filter( $true_filter, $doc, $scope, $orig_doc );
        }
        else {
            return $false_filter ? $class->filter( $false_filter, $doc, $scope, $orig_doc ) : ();
        }
    }

    # , does multiple filters, yielding multiple documents
    # This must be the least-specific rule because of all the other
    # possible uses of the comma
    # XXX: In the future, this should be used to parse function
    # arguments to allow for recursion
    elsif ( $filter =~ /,/ ) {
        my @filters = split /\s*,\s*/, $filter;
        return map { $class->filter( $_, $doc, $scope, $orig_doc ) } @filters;
    }

    else {
        die "Could not parse filter '$filter'\n";
    }
    return;
}

1;

