package Biodiverse::ReadNexus;

#  Read in a nexus tree file and extract the trees into Biodiverse::Tree files
#  Initial work by Dan Rosauer
#  regex based approach by Shawn Laffan

use strict;
use warnings;
use Carp;
use English ( -no_match_vars );

use Scalar::Util qw /looks_like_number/;

use Biodiverse::Tree;
use Biodiverse::TreeNode;

our $VERSION = '0.16';

use base qw /Biodiverse::Common/;

#  hunt for any decimal number format
use Regexp::Common qw /number/;
my $RE_NUMBER = qr /$RE{num}{real}/xms;

my $RE_TEXT_IN_QUOTES
    = qr{
        \A
        (['"])
        (.+)  #  text inside quotes is \2 and $2
        \1
        \z
    }xms;

my $EMPTY_STRING = q{};

#$text_in_brackets = qr / ( [^()] )* /x; #  from page 328, but doesn't work here
my $re_text_in_brackets;  #  straight from Friedl, page 330.  Could be overkill, but works
$re_text_in_brackets = qr / (?> [^()]+ | \(  (??{ $re_text_in_brackets }) \) )* /xo;

my $re_text_in_square_brackets;  #  modified from Friedl, page 330.
$re_text_in_square_brackets = qr / (?> [^[]]+ | \[  (??{ $re_text_in_square_brackets }) \] )* /xo;


sub new {
    my $class = shift;
    
    my %PARAMS = (
        JOIN_CHAR   => q{:},
        QUOTES      => q{'},
    );
    
    my $self = bless {
        'TREE_ARRAY' => [],
    }, $class;
    
    $self -> set_param (%PARAMS, @_);
    $self -> set_default_params;  #  and any user overrides
    
    return $self;
}

sub add_tree {
    my $self = shift;
    my %args = @_;
    
    return if ! defined $args{tree};
    
    push @{$self->{TREE_ARRAY}}, $args{tree};
  
}



#  now we need to set up the methods to load the tree etc

sub import_data {
    my $self = shift;
    my %args = @_;
    
    my $element_properties = $args{element_properties};
    my $use_element_properties = exists $args{use_element_properties}  #  just a flag of convenience
                                    ? $args{use_element_properties}
                                    : defined $element_properties;
    $self -> set_param (ELEMENT_PROPERTIES => $element_properties);
    $self -> set_param (USE_ELEMENT_PROPERTIES => $use_element_properties);
    
    eval {
        $self -> import_nexus (%args);
    };
    if ($EVAL_ERROR) {
        eval {
            $self -> import_newick (%args);
        };
        croak $EVAL_ERROR if $EVAL_ERROR;
    }

    $self->process_zero_length_trees;
    $self->process_unrooted_trees;

    return 1;
}

#  import the tree from a newick file
sub import_newick {
    my $self = shift;
    my %args = @_;

    my $newick = $args{data};

    croak "Neither file nor data arg specified\n"
        if not defined $newick and not defined $args{file};

    if (! defined $newick) {
        $newick = $self -> read_whole_file (file => $args{file});
    }

    my $tree = Biodiverse::Tree -> new (
        NAME => $args{NAME}
            || 'anonymous from newick'
        );

    my $count = 0;
    my $node_count = \$count;

    $self -> parse_newick (
        string          => $newick,
        tree            => $tree,
        node_count      => $node_count,
    );
    
    $self -> add_tree (tree => $tree);

    return 1;
}

# import the trees from a nexus file
sub import_nexus {
    my $self = shift;
    my %args = @_;

    my $nexus = $args{data};

    croak "Neither file nor data arg specified\n"
      if not defined $nexus and not defined $args{file};

    if (! defined $nexus) {
        $nexus = $self -> read_whole_file (file => $args{file});
    }

    my @nexus = split (/[\r\n]+/, $nexus);
    my %translate;
    my @newicks;

    pos ($nexus) = 0;
    my $in_trees_block = 0;

    #  now we extract the tree block
    BY_LINE:
    while (defined (my $line = shift @nexus)) {  #  haven't hit the end of the file yet
        #print "position is " . pos ($nexus) . "\n";

        # skip any lines before the tree block
        if (not $in_trees_block and $line =~ m/\s*begin trees;/i) {
            $in_trees_block = 1;
            $line = shift @nexus;  #  get the next line now we're in the trees block
            next BY_LINE if not defined $line;
        }

        next BY_LINE if not $in_trees_block;

        #print "$line\n";

        #  drop out if we are at the end or endblock that closes the trees block
        last if $line =~ m/\s*end(?:block)?;/i;

        #  now we are in the tree block, process the lines as appropriate

        if ($line =~ m/^\s*\[/) {  #  comment - munch to the end of the comment
            next BY_LINE if $line =~ /\]/;  #  comment closer is on this line
            while (my $comment = shift @nexus) {
                next unless $comment =~ /\]/;
                next BY_LINE;  #  we hit the closing comment marker, move to the next line
            }
        }
        elsif ($line =~ m/\s*Translate/i) {  #  translate block - munch to the end of it and store the translations

            TRANSLATE_BLOCK:
            while (my $trans = shift @nexus) {
                #print "$trans\n";
                my ($trans_code, $trans_name)
                    = $trans =~  m{  \s*     #  zero or more whitespace chars
                                    (\S+)    #  typically a number
                                     \s+     #  one or more whitespace chars
                                    (\S+)    #  the label
                                  }x;
                if (defined $trans_code) {
                    #  delete trailing comma or semicolon
                    $trans_name =~ s{ [,;]
                                      \s*
                                      \z
                                    }
                                    {}xms;
                    if (my @components = $trans_name =~ $RE_TEXT_IN_QUOTES) {
                        $trans_name = $components[1];
                    }
                    $translate{$trans_code} = $trans_name;
                }
                last TRANSLATE_BLOCK if $trans =~ /;\s*\z/;  #  semicolon marks the end
            }
        }
        elsif ($line =~ m/\s*tree/i) {  #  tree - extract it

            my $nwk = $line;
            if (not $line =~ m/;\s*$/) {  #  tree is not finished unless we end in a semi colon, maybe with some white space
                
                TREE_LINES:
                while (my $tree_line = shift @nexus) {
                    $tree_line =~ s{[\r\n]} {};  #  delete any newlines, although they should already be gone...
                    $nwk .= $tree_line;
                    last if $tree_line =~ m/;\s*$/;  #  ends in a semi-colon
                }
            }

            push @newicks, $nwk;
        }
    }

    croak "File appears not to be a nexus format or has no trees in it\n"
        if scalar @newicks == 0;

    $self -> set_param (TRANSLATE_HASH => \%translate);  #  store for future use

    foreach my $nwk (@newicks) {

            #  remove trailing semi-colon
            $nwk =~ s/;$//;

            my $tree_name = $EMPTY_STRING;
            my $rooted    = $EMPTY_STRING;
            my $rest      = $EMPTY_STRING;

            #  get the tree name and whether it is unrooted etc
            if (my $x = $nwk =~ m/
                                \s*
                                tree\s+
                                (.+)       #  capture the name of the tree into $1
                                \s*=\s*
                                (\[..\])?  #  get the rooted unrooted bit
                                \s*
                                (.*)     #  get the rest
                            /xgcsi
            ) {

                $tree_name = $1;
                $rooted    = $2;
                $rest      = $3;
            }

            $tree_name =~ s/\s+$//;  #  trim trailing whitespace

            my $tree = Biodiverse::Tree -> new (NAME => $tree_name);
            #$tree -> set_param ()

            my $count = 0;
            my $node_count = \$count;

            $self -> parse_newick (
                string          => $rest,
                tree            => $tree,
                node_count      => $node_count,
                translate_hash  => \%translate,
            );

            $self -> add_tree (tree => $tree);
    }
    
    #print "";
    
    return 1;
}

sub process_unrooted_trees {
    my $self = shift;
    my @trees = $self -> get_tree_array;
    
    BY_LOADED_TREE:
    foreach my $tree (@trees) {
        $tree->root_unrooted_tree;
    }
    
    return;
}

sub process_zero_length_trees {
    my $self = shift;
    
    my @trees = $self -> get_tree_array;
    
    #  now we check if the tree has all zero-length nodes.  Change these to length 1.
    BY_LOADED_TREE:
    foreach my $tree (@trees) {
        my %nodes = $tree -> get_node_hash;
        my $len_sum = 0;

        LEN_SUM:
        foreach my $node (values %nodes) {
            $len_sum += $node -> get_length;
            last LEN_SUM if $len_sum;  #  drop out if we have a non-zero length
        }

        if ($len_sum == 0) {
            print "[READNEXUS] All nodes are of length zero, converting all to length 1\n";
            foreach my $node (values %nodes) {
                $node -> set_length (length => 1);
            }
        }
    }

    return;
}

sub read_whole_file {
    my $self = shift;
    my %args = @_;
    
    my $file = $args{file};

    croak "file arg not specified\n"
        if not defined $file;

    #  now we open the file and suck it al in
    my $fh;
    open ($fh, '<', $file)
      || croak "[READNEXUS] cannot open $file for reading\n";

    local $/ = undef;
    my $text = <$fh>;  #  suck the whole thing in
    $fh -> close || croak "Cannot close $file\n";

    return $text;
}


#  parse the sub tree into its component nodes
sub parse_newick {
    my $self = shift;
    my %args = @_;

    my $string = $args{string};
    my $str_len = length ($string);
    my $tree = $args{tree};
    my $tree_name = $tree -> get_param ('NAME');

    my $node_count             = $args{node_count};
    my $translate_hash         = $args{translate_hash}
                               || $self -> get_param ('TRANSLATE_HASH');
    my $element_properties     = $args{element_properties}
                               || $self -> get_param ('ELEMENT_PROPERTIES');
    my $use_element_properties = $self -> get_param ('USE_ELEMENT_PROPERTIES');

    my $quote_char = $self -> get_param ('QUOTES') || q{'};
    my $csv_obj    = $self -> get_csv_object (quote_char => $quote_char);

    my $name;

    my $default_length = 0;
    my $length = $default_length;
    my $boot_value;

    my @nodes_added;
    my @children_of_current_node;

    pos ($string) = 0;

    while (not $string =~ m/ \G \z /xgcs) {  #  haven't hit the end of line yet
        #print "\nParsing $string\n";
        #print "Nodecount is $$node_count\n";
        #print "Position is " . (pos $string) . " of $str_len\n";

        #  march through any whitespace and newlines
        if ($string =~ m/ \G [\s\n\r]+ /xgcs) {  
            #print "found some whitespace\n";
            #print "Position is " . (pos $string) . " of $str_len\n";
        }

        #  we have a comma or are at the end of the string, so we create this node and start a new one
        elsif ($string =~ m/ \G (,)/xgcs) {  
            #if ($1 =~ /,/) {  
            ##    #print "found a comma\n";
            #}
            #else {
            #    #print "hit the end of line\n";
            #}
            #print "Position is " . (pos $string) . " of $str_len\n";
            if (not defined $name) {
                $name = $tree -> get_free_internal_name (
                    exclude => $translate_hash,
                );
            }
            if (exists $translate_hash->{$name}) {
                $name = $translate_hash->{$name} ;
            }
            $name =~ s{^$quote_char} {};  #  strip any bounding quotes - let the next csv line decide
            $name =~ s{$quote_char$} {};
            #  and now we need to make the name use the CSV rules used everywhere else
            $name = $self -> list2csv (csv_object => $csv_obj, list => [$name]);
            if ($use_element_properties) {
                my $element = $element_properties -> get_element_remapped (
                    element => $name,
                );
                
                my $original_name = $name;
                
                if (defined $element) {
                    $name = $element;
                    print "$tree_name: Remapped $original_name to $element\n";
                }
            }

            #print "Adding new node to tree, name is $name, length is $length\n";
            my $node = $tree -> add_node (name => $name, length => $length, boot => $boot_value);
            push @nodes_added, $node;
            #  add any relevant children
            if (scalar @children_of_current_node) {
                $node -> add_children (children => \@children_of_current_node);
            }
            #  reset name, length and children
            $$node_count ++;
            $name = undef;
            $length = undef;
            @children_of_current_node = ();
            $boot_value = undef;
        }

        #  use positive look-ahead to find if we start with an opening bracket
        elsif ($string =~ m/ \G (?= \( ) /xgcs) {  
            #print "found an open bracket\n";
            #print "Position is " . (pos $string) . " of $str_len\n";
            
            if ($string =~ m/\G \( ( $re_text_in_brackets) \) /xgcs) {
                my $sub_newick = $1;
                #print "Eating to closing bracket\n";
                #print "Position is " . (pos $string) . " of $str_len\n";
                
                @children_of_current_node = $self -> parse_newick (
                    string => $sub_newick,
                    tree => $tree,
                    node_count => $node_count,
                    translate_hash => $translate_hash,
                );
            }
            else {
                pos $string = 0;
                my @left  = ($string =~ / \( /gx);
                my @right = ($string =~ / \) /gx);
                my $left_count  = scalar @left;
                my $right_count = scalar @right;
                croak "Tree has unbalanced parentheses "
                      . "(left is $left_count, "
                      . "right is $right_count), "
                      . "unable to parse\n";
            }
        }

        #  do we have a square bracket for bootstrap and other values?
        elsif ($string =~ m/ \G (?= \[ ) /xgcs) {  
            #print "found an open square bracket\n";
            #print "Position is " . (pos $string) . " of $str_len\n";
            
            $string =~ m/\G \[ ( .*? ) \] /xgcs;
            #print "Eating to closing square bracket\n";
            #print "Position is " . (pos $string) . " of $str_len\n";
            
            $boot_value = $1;
        }

        #  we have found a quote char, match to the next quote
        elsif ($string =~ m/ \G '/xgcs) { 
            #print "found a quote char\n";
            #print "Position is " . (pos $string) . " of $str_len\n";
            
            $string =~ m/\G (.*?) '/xgcs;  #  eat up to the next quote
            $name = $1;
        }

        #  next value is a length if we have a colon
        elsif ($string =~ m/ \G :/xgcs) {  
            #print "found a length value\n";
            #print "Position is " . (pos $string) . " of $str_len\n";

            #  get the number - assumes it is in standard decimal form
            #$string =~ m/\G (\d* \.? \d*) /xgcs;
            $string =~ m/\G ( $RE_NUMBER ) /xgcs;
            #print "length value is $1\n";
            $length = $1;
            croak "Length $length does not look like a number\n"
                if ! looks_like_number $length;
            $length += 0;  #  make it numeric
            my $x = $length;
        }

        #  next value is a name, but it can be empty
        #elsif ($string =~ m/ \G ( [\w\d]* )  /xgcs) {
        #  anything except special chars is fair game
        elsif ($string =~ m/ \G ( [^(),:'\[\]]* )  /xgcs) {  
            #print "found a name value $1\n";
            #print "\tbut it is anonymous\n" if length ($1) == 0;
            #print "Position is " . (pos $string) . " of $str_len\n";
            
            #$string =~ m/\G (.+?)\b /xgcs;  #  match to the next word boundary
            $name = $1;
        }

        #  unexpected character found, or other failure - croak
        else { 
            #print "found nothing valid\n";
            #print "Position is " . (pos $string) . " of $str_len\n";
            #print "$string\n";
            $string =~ m/ \G ( . )  /xgcs;
            my $char = $1;
            my $posn = pos ($string);
            croak "[ReadNexus] Unexpected character '$char' found at position $posn\n";
        }  
    }
    
    
    #print "hit the end of line\n";
    #print "Position is " . (pos $string) . " of $str_len\n";
    
    #  the following is a duplicate of code from above, but converting to a sub uses
    #  almost as many lines as the two blocks combined
    if (not defined $name) {
        #print "Tree is $tree";
        $name = $tree -> get_free_internal_name (exclude => $translate_hash);
    }
    if (exists $translate_hash->{$name}) {
        $name = $translate_hash->{$name};
    }
    
    #  strip any quotes - let list2csv decide
    if (my @components = $name =~ $RE_TEXT_IN_QUOTES) {
        $name = $components[1];
    }
    
    #  and now we need to make the name use the CSV rules used everywhere else
    $name = $self -> list2csv (csv_object => $csv_obj, list => [$name]);
    
    if ($use_element_properties) {
        my $element = $element_properties -> get_element_remapped (element => $name);
        my $original_name = $name;
        $name = $element if defined $element;
        if (defined $element) {
            print "$tree_name: Remapped $original_name to $element\n";
        }
    }
    
    #print "Adding new node to tree, name is $name, length is $length\n";
    my $node = eval {
        $tree -> add_node (
            name   => $name,
            length => $length,
            boot   => $boot_value,
        )
    };
    croak $EVAL_ERROR if $EVAL_ERROR;
    
    push @nodes_added, $node;
    #  add any relevant children
    $node -> add_children (children => \@children_of_current_node) if scalar @children_of_current_node;
    
    return wantarray ? @nodes_added : \@nodes_added;
}


#  SWL: method to get the tree array.  Needed for GUI.
sub get_tree_array {
  my $self = shift;
  return wantarray ? @{$self->{TREE_ARRAY}} : $self->{TREE_ARRAY};
}

sub numerically {$a <=> $b};


1;


__END__

=head1 NAME

Biodiverse::????

=head1 SYNOPSIS

  use Biodiverse::????;
  $object = Biodiverse::Statistics->new();

=head1 DESCRIPTION

TO BE FILLED IN

=head1 METHODS

=over

=item INSERT METHODS

=back

=head1 REPORTING ERRORS

Use the issue tracker at http://www.purl.org/biodiverse

=head1 COPYRIGHT

Copyright (c) 2010 Shawn Laffan. All rights reserved.  

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

For a full copy of the license see <http://www.gnu.org/licenses/>.

=cut
