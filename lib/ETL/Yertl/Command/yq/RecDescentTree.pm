package ETL::Yertl::Command::yq::RecDescentTree;
# ABSTRACT: A Parse::RecDescent-based parser using a parse tree

use ETL::Yertl;
use boolean qw( :all );
use Parse::RecDescent;

$|++;
$::RD_ERRORS = 1;
#$::RD_WARN = 1;
#$::RD_HINT = 1;
#$::RD_TRACE = 1;

use Data::Dumper;
use boolean qw( true false );
sub one { return is_list( $_[0] ) ? $_[0]->[0] : $_[0] }
sub is_list { return ref $_[0] eq 'list' }
sub flatten { map { is_list( $_ ) ? @$_ : $_ } @_ }
sub list { return bless [ flatten( @_ ) ], 'list' }
sub empty { return bless {}, 'empty' }

my $grammar = q{
    <autotree>
    { use Data::Dumper }

    program: <leftop: statement comb statement>

    comb: '|' | ','

    statement: conditional | expr

    conditional: 'if' cond_expr 'then' true_expr ( 'else' false_expr )(?)

    cond_expr: expr
    true_expr: expr
    false_expr: expr

    expr: function_call | hash | array | binop | filter | quote_string | number | word

    filter: '.' <skip:""> filter_part(s? /[.]/)

    filter_part: word | '[' number(?) ']'

    binop: (filter|quote_string|number|word) op (filter|quote_string|number|word)

    function_call: function_name arguments(?)

    hash: '{' pair(s /,/) '}'

    array: '[' expr(s /,/) ']'

    arguments: '(' expr(s /,/) ')'

    pair: key ':' expr

    key: filter | quote_string | word

    quote_string: quote non_quote quote
        { $return = eval join "", map { $_->{__VALUE__} } @item[1..$#item] }

    number: binnum | hexnum | octnum | float
        { $return = $item[1] }

    binnum: /0b[01]+/
        { $return = eval $item[1] }

    hexnum: /0x[0-9A-Fa-f]+/
        { $return = eval $item[1] }

    octnum: /0o?\d+/
        { $return = eval $item[1] }

    float: /-?\d+(?:[.]\d+)?(?:e\d+)?/
        { $return = eval $item[1] }

    word: /\w+/

    quote: /(?<!\\\\)['"]/

    non_quote: /(?:[^'"]|(?<=\\\\)['"])+/

    function_name: "empty" | "select" | "grep" | "group_by" | "keys" | "length" | "sort"

    op: "eq" | "ne" | "==" | "!=" | ">=" | ">" | "<=" | "<"

    comb: ',' | '|'
};

my $parser = Parse::RecDescent->new( $grammar );

sub filter {
    my ( $class, $filter, $doc, $scope ) = @_;
    $yq::VERBOSE = 1;

    my $tree = $parser->program( $filter );
    #use Data::Dumper;
    #print Dumper $tree;
    #exit;

    my @parts = @{ $tree->{__DIRECTIVE1__} };
    my @input = ( $doc );
    my @output;
    my $i = 0;
    while ( $i < @parts ) {
        if ( $i > 0 && $parts[$i-1]->{__VALUE__} eq '|' ) {
            @output = ();
        }

        for my $input ( @input ) {
            push @output, run_statement( $parts[$i], $input, $scope );
        }

        if ( $i < @parts-1 ) {
            if ( $parts[$i+1]->{__VALUE__} eq '|' ) {
                @input = @output;
            }
        }
        $i += 2; # Always skip the odd indices
    }

    return wantarray ? @output : $output[0];
}

sub run_statement {
    my $statement = shift;

    if ( $statement->{expr} ) {
        return run_expr( $statement->{expr}, @_ );
    }
    elsif ( $statement->{conditional} ) {
        return run_conditional( $statement->{conditional}, @_ );
    }
}

sub run_conditional {
    my $cond = shift;
    if ( run_expr( $cond->{cond_expr}{expr}, @_ ) ) {
        return run_expr( $cond->{true_expr}{expr}, @_ );
    }
    elsif ( my $false_exprs = $cond->{'_alternation_1_of_production_1_of_rule_conditional(?)'} ) {
        return run_expr( $false_exprs->[0]{false_expr}{expr}, @_ );
    }
    return;
}

sub run_expr {
    my $expr = shift;
    if ( $expr->{filter} ) {
        return run_filter( $expr->{filter}, @_ );
    }
    if ( $expr->{binop} ) {
        return run_binop( $expr->{binop}, @_ );
    }
    if ( $expr->{hash} ) {
        return run_hash( $expr->{hash}, @_ );
    }
    if ( $expr->{array} ) {
        return run_array( $expr->{array}, @_ );
    }
    return $expr->{quote_string} // $expr->{number} // $expr->{word};
}

sub run_filter {
    my ( $filter, $document, $scope ) = @_;
    yq::diag( 1, "Filter: " . Dumper $filter );
    if ( !$filter->{'filter_part(s?)'} ) {
        return $document;
    }
    for my $part ( @{ $filter->{'filter_part(s?)'} } ) {
        if ( $part->{word} ) {
            $document = $document->{ $part->{word}{__VALUE__} };
        }
        elsif ( my $indexes = $part->{'number(?)'} ) {
            if ( !@$indexes ) {
                return @{ $document };
            }
            else {
                $document = $document->[ $indexes->[0] ];
            }
        }
    }
    yq::diag( 1, "Filter returns: " . Dumper $document );
    return $document;
}

sub run_binop {
    my $binop = shift;
    yq::diag( 1, 'binop: ' . Dumper $binop );
    my $lhs_value = run_expr( $binop->{'_alternation_1_of_production_1_of_rule_binop'}, @_ );
    my $rhs_value = run_expr( $binop->{'_alternation_2_of_production_1_of_rule_binop'}, @_ );
    my $op = $binop->{op}{__VALUE__};
    # These operators suppress undef warnings, treating undef as just
    # another value. Undef will never be treated as '' or 0 here.
    if ( $op eq 'eq' ) {
        return defined $lhs_value == defined $rhs_value
            && $lhs_value eq $rhs_value ? true : false;
    }
    elsif ( $op eq 'ne' ) {
        return defined $lhs_value != defined $rhs_value
            || $lhs_value ne $rhs_value ? true : false;
    }
    elsif ( $op eq '==' ) {
        return defined $lhs_value == defined $rhs_value
            && $lhs_value == $rhs_value ? true : false;
    }
    elsif ( $op eq '!=' ) {
        return defined $lhs_value != defined $rhs_value
            || $lhs_value != $rhs_value ? true : false;
    }
    # These operators allow undef warnings, since equating undef to 0 or ''
    # can be a cause of problems.
    elsif ( $op eq '>' ) {
        return $lhs_value > $rhs_value ? true : false;
    }
    elsif ( $op eq '>=' ) {
        return $lhs_value >= $rhs_value ? true : false;
    }
    elsif ( $op eq '<' ) {
        return $lhs_value < $rhs_value ? true : false;
    }
    elsif ( $op eq '<=' ) {
        return $lhs_value <= $rhs_value ? true : false;
    }
    return;
}

# XXX

sub run_hash {
    my $hash = shift;
    my $return = {};
    yq::diag( 1, "Hash: " . Dumper $hash );
    for my $pair ( @{ $hash->{'pair(s /,/)'} } ) {
        $return->{ run_expr( $pair->{key}, @_ ) } = run_expr( $pair->{expr}, @_ );
    }
    return $return;
}

sub run_array {
    my $array = shift;

    return [];
}

1;
